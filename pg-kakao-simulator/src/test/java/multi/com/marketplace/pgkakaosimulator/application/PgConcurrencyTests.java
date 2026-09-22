package multi.com.marketplace.pgkakaosimulator.application;

import java.util.*;
import java.util.concurrent.*;
import multi.com.marketplace.pgkakaosimulator.domain.PgPayment;
import multi.com.marketplace.pgkakaosimulator.infrastructure.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class PgConcurrencyTests {
    @Autowired PgKakaoSimulatorService service;
    @Autowired JdbcTemplate jdbc;

    @Test
    void simultaneousApprovalsReturnOneCommittedPaymentAndOneLedgerEntry() throws Exception {
        String merchant = "race-" + UUID.randomUUID();
        var values = race(8, () -> service.approve(new PgKakaoSimulatorService.ApproveCommand(
                merchant, "KRW", 1000, "key-" + merchant)));
        assertEquals(1, values.stream().map(PgPayment::paymentId).distinct().count());
        UUID id = values.get(0).paymentId();
        assertEquals(1L, jdbc.queryForObject(
                "select count(*) from pgkakao.pg_transaction where payment_id = ?", Long.class, id));
    }

    @Test
    void concurrentRefundRetriesHaveOnlyOneFinancialEffect() throws Exception {
        String merchant = "refund-race-" + UUID.randomUUID();
        var payment = service.approve(new PgKakaoSimulatorService.ApproveCommand(merchant, "KRW", 1000, merchant));
        race(8, () -> service.refund(payment.paymentId(), new PgKakaoSimulatorService.RefundCommand(700, "same")));
        assertEquals(700, service.findPayment(payment.paymentId()).refundedAmount());
        assertEquals(1L, jdbc.queryForObject(
                "select count(*) from pgkakao.pg_transaction where payment_id = ? and transaction_type = 'REFUND'",
                Long.class, payment.paymentId()));
    }

    @Test
    void competingDifferentRefundsCannotExceedPaymentAmount() throws Exception {
        String merchant = "over-refund-" + UUID.randomUUID();
        var payment = service.approve(new PgKakaoSimulatorService.ApproveCommand(merchant, "KRW", 1000, merchant));
        var results = race(2, () -> {
            try {
                service.refund(payment.paymentId(), new PgKakaoSimulatorService.RefundCommand(700, UUID.randomUUID().toString()));
                return true;
            } catch (PgKakaoSimulatorException ex) {
                assertEquals(PgKakaoSimulatorErrorCode.REFUND_AMOUNT_INVALID, ex.errorCode());
                return false;
            }
        });
        assertEquals(1, results.stream().filter(Boolean::booleanValue).count());
        assertEquals(700, service.findPayment(payment.paymentId()).refundedAmount());
    }

    private static <T> List<T> race(int count, Callable<T> action) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(count);
        CountDownLatch ready = new CountDownLatch(count);
        CountDownLatch start = new CountDownLatch(1);
        try {
            List<Future<T>> futures = new ArrayList<>();
            for (int i = 0; i < count; i++) futures.add(pool.submit(() -> {
                ready.countDown();
                if (!start.await(10, TimeUnit.SECONDS)) throw new AssertionError("start timeout");
                return action.call();
            }));
            assertTrue(ready.await(10, TimeUnit.SECONDS));
            start.countDown();
            List<T> values = new ArrayList<>();
            for (Future<T> future : futures) values.add(future.get(30, TimeUnit.SECONDS));
            return values;
        } finally {
            start.countDown();
            pool.shutdownNow();
        }
    }
}
