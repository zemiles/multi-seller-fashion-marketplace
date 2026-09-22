package multi.com.marketplace.pgnaversimulator.api;

import java.util.UUID;
import multi.com.marketplace.pgnaversimulator.application.PgNaverSimulatorService;
import multi.com.marketplace.pgnaversimulator.domain.PgPayment;
import multi.com.marketplace.pgsimulatorcommon.api.PgApproveRequest;
import multi.com.marketplace.pgsimulatorcommon.api.PgCancelRequest;
import multi.com.marketplace.pgsimulatorcommon.api.PgPaymentResponse;
import multi.com.marketplace.pgsimulatorcommon.api.PgRefundRequest;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/pg/v1")
public class PgNaverSimulatorController {
    private final PgNaverSimulatorService service;

    public PgNaverSimulatorController(PgNaverSimulatorService service) {
        this.service = service;
    }

    @PostMapping("/payments/approve")
    public PgPaymentResponse approve(@RequestBody PgApproveRequest request) {
        return response(service.approve(new PgNaverSimulatorService.ApproveCommand(request.merchantTxId(), request.currency(),
                request.amount(), request.idempotencyKey())));
    }

    @PostMapping("/payments/{paymentId}/cancel")
    public PgPaymentResponse cancel(@PathVariable("paymentId") UUID paymentId, @RequestBody PgCancelRequest request) {
        return response(service.cancel(paymentId, new PgNaverSimulatorService.CancelCommand(request.idempotencyKey())));
    }

    @PostMapping("/payments/{paymentId}/refund")
    public PgPaymentResponse refund(@PathVariable("paymentId") UUID paymentId, @RequestBody PgRefundRequest request) {
        return response(service.refund(paymentId, new PgNaverSimulatorService.RefundCommand(request.amount(), request.idempotencyKey())));
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


