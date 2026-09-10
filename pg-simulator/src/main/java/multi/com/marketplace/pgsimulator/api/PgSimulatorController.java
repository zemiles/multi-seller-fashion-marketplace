package multi.com.marketplace.pgsimulator.api;

import java.util.UUID;
import multi.com.marketplace.pgsimulator.domain.PgPayment;
import multi.com.marketplace.pgsimulator.domain.PgPaymentStatus;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/pg/v1")
public class PgSimulatorController {
    private final JdbcTemplate jdbc;
    public PgSimulatorController(JdbcTemplate jdbc) { this.jdbc = jdbc; }
    @PostMapping("/payments/approve")
    public synchronized PgPaymentResponse approve(@RequestBody ApproveRequest r) {
        if (r.amount() <= 0 || r.currency() == null || !r.currency().matches("[A-Z]{3}")) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid amount or currency");
        PgPayment old = findByMerchantTx(r.merchantTxId()); if (old != null) return response(old);
        UUID id = UUID.randomUUID();
        jdbc.update("INSERT INTO pgsim.pg_payment(payment_id,merchant_tx_id,currency,amount) VALUES (?,?,?,?)", id,r.merchantTxId(),r.currency(),r.amount());
        jdbc.update("INSERT INTO pgsim.pg_transaction(transaction_id,payment_id,transaction_type,amount,status) VALUES (? ,?,'APPROVE',?,'SUCCEEDED')", UUID.randomUUID(), id,r.amount());
        return response(require(id));
    }
    @PostMapping("/payments/{paymentId}/cancel")
    public synchronized PgPaymentResponse cancel(@PathVariable("paymentId") UUID id) {
        PgPayment p=require(id); if(p.status()!=PgPaymentStatus.APPROVED) throw new ResponseStatusException(HttpStatus.CONFLICT,"Payment cannot be cancelled");
        jdbc.update("UPDATE pgsim.pg_payment SET status='CANCELLED',updated_at=now() WHERE payment_id=?",id);
        jdbc.update("INSERT INTO pgsim.pg_transaction(transaction_id,payment_id,transaction_type,amount,status) VALUES (?,?, 'CANCEL',?,'SUCCEEDED')",UUID.randomUUID(),id,p.amount()); return response(require(id));
    }
    @PostMapping("/payments/{paymentId}/refund")
    public synchronized PgPaymentResponse refund(@PathVariable("paymentId") UUID id,@RequestBody RefundRequest r) {
        PgPayment u; try {u=require(id).refund(r.amount());} catch(IllegalArgumentException e){throw new ResponseStatusException(HttpStatus.CONFLICT,e.getMessage(),e);}
        jdbc.update("UPDATE pgsim.pg_payment SET status=?,refunded_amount=?,updated_at=now() WHERE payment_id=?",u.status().name(),u.refundedAmount(),id);
        jdbc.update("INSERT INTO pgsim.pg_transaction(transaction_id,payment_id,transaction_type,amount,status) VALUES (?,?, 'REFUND',?,'SUCCEEDED')",UUID.randomUUID(),id,r.amount()); return response(u);
    }
    @GetMapping("/payments/{paymentId}") public PgPaymentResponse get(@PathVariable("paymentId") UUID id){return response(require(id));}
    private PgPayment require(UUID id){try{return jdbc.queryForObject("SELECT payment_id,merchant_tx_id,currency,amount,status,refunded_amount,created_at,updated_at FROM pgsim.pg_payment WHERE payment_id=?",(rs,n)->new PgPayment(rs.getObject("payment_id",UUID.class),rs.getString("merchant_tx_id"),rs.getString("currency"),rs.getLong("amount"),PgPaymentStatus.valueOf(rs.getString("status")),rs.getLong("refunded_amount"),rs.getTimestamp("created_at").toInstant(),rs.getTimestamp("updated_at").toInstant()),id);}catch(EmptyResultDataAccessException e){throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Payment not found");}}
    private PgPayment findByMerchantTx(String tx){try{return jdbc.queryForObject("SELECT payment_id,merchant_tx_id,currency,amount,status,refunded_amount,created_at,updated_at FROM pgsim.pg_payment WHERE merchant_tx_id=?",(rs,n)->new PgPayment(rs.getObject("payment_id",UUID.class),rs.getString("merchant_tx_id"),rs.getString("currency"),rs.getLong("amount"),PgPaymentStatus.valueOf(rs.getString("status")),rs.getLong("refunded_amount"),rs.getTimestamp("created_at").toInstant(),rs.getTimestamp("updated_at").toInstant()),tx);}catch(EmptyResultDataAccessException e){return null;}}
    private static PgPaymentResponse response(PgPayment p){return new PgPaymentResponse(p.paymentId(),p.merchantTxId(),p.currency(),p.amount(),p.status(),p.refundedAmount());}
    public record ApproveRequest(String merchantTxId,String currency,long amount){}
    public record RefundRequest(long amount){}
    public record PgPaymentResponse(UUID paymentId,String merchantTxId,String currency,long amount,PgPaymentStatus status,long refundedAmount){}
}
