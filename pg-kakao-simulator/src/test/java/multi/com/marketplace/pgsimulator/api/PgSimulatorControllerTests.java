package multi.com.marketplace.pgkakaosimulator.api;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class PgKakaoSimulatorControllerTests {
    @Autowired MockMvc mvc;

    @Test
    void approvesAndReturnsTheSamePaymentOnlyForTheSameMerchantTransactionData() throws Exception {
        String merchantTxId = "merchant-" + UUID.randomUUID();
        String body = approvalBody(merchantTxId, 10_000, "approve-key");
        String first = mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status", is("APPROVED")))
                .andReturn().getResponse().getContentAsString();
        mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andExpect(content().json(first));
        mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON)
                        .content(approvalBody(merchantTxId, 9_999, "different-key")))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code", is("KAKAO_PG_004")))
                .andExpect(jsonPath("$.message", is("동일한 가맹점 거래 번호가 다른 결제 정보에 사용되었습니다.")));
    }

    @Test
    void refundIsIdempotentAndRejectsChangedAmountForTheSameKey() throws Exception {
        String id = approve("refund-" + UUID.randomUUID());
        String first = mvc.perform(post("/pg/v1/payments/" + id + "/refund")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"amount\":4000,\"idempotencyKey\":\"refund-1\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status", is("PARTIALLY_REFUNDED")))
                .andExpect(jsonPath("$.refundedAmount", is(4000)))
                .andReturn().getResponse().getContentAsString();
        mvc.perform(post("/pg/v1/payments/" + id + "/refund")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"amount\":4000,\"idempotencyKey\":\"refund-1\"}"))
                .andExpect(status().isOk()).andExpect(content().json(first));
        mvc.perform(post("/pg/v1/payments/" + id + "/refund")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"amount\":3000,\"idempotencyKey\":\"refund-1\"}"))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code", is("KAKAO_PG_007")));
        mvc.perform(post("/pg/v1/payments/" + id + "/refund")
                        .contentType(MediaType.APPLICATION_JSON).content("{\"amount\":6000,\"idempotencyKey\":\"refund-2\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status", is("REFUNDED")))
                .andExpect(jsonPath("$.refundedAmount", is(10000)));
    }

    @Test
    void cancelIsIdempotentAndCancelledPaymentsCannotBeRefunded() throws Exception {
        String id = approve("cancel-" + UUID.randomUUID());
        String cancelBody = "{\"idempotencyKey\":\"cancel-1\"}";
        mvc.perform(post("/pg/v1/payments/" + id + "/cancel").contentType(MediaType.APPLICATION_JSON).content(cancelBody))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status", is("CANCELLED")));
        mvc.perform(post("/pg/v1/payments/" + id + "/cancel").contentType(MediaType.APPLICATION_JSON).content(cancelBody))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status", is("CANCELLED")));
        mvc.perform(post("/pg/v1/payments/" + id + "/refund").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"amount\":10000,\"idempotencyKey\":\"refund-after-cancel\"}"))
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code", is("KAKAO_PG_005")));
    }

    @Test
    void rejectsInvalidApprovalAndUnknownPayment() throws Exception {
        mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON)
                .content("{\"merchantTxId\":\" \",\"currency\":\"krw\",\"amount\":0,\"idempotencyKey\":\" \"}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code", is("KAKAO_PG_001")))
                .andExpect(jsonPath("$.message", is("요청 값이 올바르지 않습니다.")));
        mvc.perform(get("/pg/v1/payments/" + UUID.randomUUID()))
                .andExpect(status().isNotFound()).andExpect(jsonPath("$.code", is("KAKAO_PG_003")));
    }

    @Test
    void returnsCommonErrorCodesForHttpFailures() throws Exception {
        mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON).content("{"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code", is("HTTP_400_001")));
        mvc.perform(put("/pg/v1/payments/approve"))
                .andExpect(status().isMethodNotAllowed()).andExpect(jsonPath("$.code", is("HTTP_405_001")));
        mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.TEXT_PLAIN).content("요청"))
                .andExpect(status().isUnsupportedMediaType()).andExpect(jsonPath("$.code", is("HTTP_415_001")));
        mvc.perform(get("/pg/v1/unknown"))
                .andExpect(status().isNotFound()).andExpect(jsonPath("$.code", is("HTTP_404_001")));
    }

    private String approve(String merchantTxId) throws Exception {
        String response = mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON)
                        .content(approvalBody(merchantTxId, 10_000, "approve-" + merchantTxId)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return response.replaceFirst(".*\\\"paymentId\\\":\\\"([^\\\"]+).*", "$1");
    }

    @Test
    void rejectsFractionalAndStringAmountsInsteadOfCoercingMoney() throws Exception {
        for (String amount : new String[]{"1000.5", "\"1000\""}) {
            String body = "{\"merchantTxId\":\"strict-" + UUID.randomUUID()
                    + "\",\"currency\":\"KRW\",\"amount\":" + amount + ",\"idempotencyKey\":\"strict\"}";
            mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON).content(body))
                    .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code", is("HTTP_400_001")));
        }
    }

    private static String approvalBody(String merchantTxId, long amount, String idempotencyKey) {
        return "{\"merchantTxId\":\"" + merchantTxId + "\",\"currency\":\"KRW\",\"amount\":" + amount
                + ",\"idempotencyKey\":\"" + idempotencyKey + "\"}";
    }

}

