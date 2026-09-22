package multi.com.marketplace.pgkakaosimulator.api;

import java.util.UUID;
import multi.com.marketplace.pgkakaosimulator.application.PgKakaoSimulatorService;
import multi.com.marketplace.pgkakaosimulator.domain.PgPayment;
import multi.com.marketplace.pgsimulatorcommon.api.PgApproveRequest;
import multi.com.marketplace.pgsimulatorcommon.api.PgCancelRequest;
import multi.com.marketplace.pgsimulatorcommon.api.PgPaymentResponse;
import multi.com.marketplace.pgsimulatorcommon.api.PgRefundRequest;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/pg/v1")
public class PgKakaoSimulatorController {
    private final PgKakaoSimulatorService service;

    public PgKakaoSimulatorController(PgKakaoSimulatorService service) {
        this.service = service;
    }

    @PostMapping("/payments/approve")
    public PgPaymentResponse approve(@RequestBody PgApproveRequest request) {
        return response(service.approve(new PgKakaoSimulatorService.ApproveCommand(request.merchantTxId(), request.currency(),
                request.amount(), request.idempotencyKey())));
    }

    @PostMapping("/payments/{paymentId}/cancel")
    public PgPaymentResponse cancel(@PathVariable("paymentId") UUID paymentId, @RequestBody PgCancelRequest request) {
        return response(service.cancel(paymentId, new PgKakaoSimulatorService.CancelCommand(request.idempotencyKey())));
    }

    @PostMapping("/payments/{paymentId}/refund")
    public PgPaymentResponse refund(@PathVariable("paymentId") UUID paymentId, @RequestBody PgRefundRequest request) {
        return response(service.refund(paymentId, new PgKakaoSimulatorService.RefundCommand(request.amount(), request.idempotencyKey())));
    }

    @GetMapping("/payments/{paymentId}")
    public PgPaymentResponse get(@PathVariable("paymentId") UUID paymentId) {
        return response(service.findPayment(paymentId));
    }

    private static PgPaymentResponse response(PgPayment payment) {
        return new PgPaymentResponse(payment.paymentId(), payment.merchantTxId(), payment.currency(),
                payment.amount(), payment.status().name(), payment.refundedAmount());
    }

}

