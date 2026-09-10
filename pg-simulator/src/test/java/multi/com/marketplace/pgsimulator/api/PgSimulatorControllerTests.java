package multi.com.marketplace.pgsimulator.api;

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
class PgSimulatorControllerTests {
    @Autowired MockMvc mvc;

    @Test
    void approvesAndReturnsTheSamePaymentForDuplicateMerchantTransaction() throws Exception {
        String merchantTxId = "merchant-" + UUID.randomUUID();
        String body = "{\"merchantTxId\":\"" + merchantTxId + "\",\"currency\":\"KRW\",\"amount\":10000}";
        String first = mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status", is("APPROVED")))
                .andReturn().getResponse().getContentAsString();
        mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andExpect(content().json(first));
    }

    @Test
    void supportsCancelAndPartialThenFullRefund() throws Exception {
        String body = "{\"merchantTxId\":\"refund-" + UUID.randomUUID() + "\",\"currency\":\"KRW\",\"amount\":10000}";
        String response = mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON).content(body))
                .andReturn().getResponse().getContentAsString();
        String id = response.replaceFirst(".*\\\"paymentId\\\":\\\"([^\\\"]+).*", "$1");
        mvc.perform(post("/pg/v1/payments/" + id + "/refund").contentType(MediaType.APPLICATION_JSON).content("{\"amount\":4000}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status", is("PARTIALLY_REFUNDED")))
                .andExpect(jsonPath("$.refundedAmount", is(4000)));
        mvc.perform(post("/pg/v1/payments/" + id + "/refund").contentType(MediaType.APPLICATION_JSON).content("{\"amount\":6000}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status", is("REFUNDED")))
                .andExpect(jsonPath("$.refundedAmount", is(10000)));
        mvc.perform(post("/pg/v1/payments/" + id + "/refund").contentType(MediaType.APPLICATION_JSON).content("{\"amount\":1}"))
                .andExpect(status().isConflict());
    }

    @Test
    void rejectsInvalidApprovalAndUnknownPayment() throws Exception {
        mvc.perform(post("/pg/v1/payments/approve").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"merchantTxId\":\"bad\",\"currency\":\"krw\",\"amount\":0}"))
                .andExpect(status().isBadRequest());
        mvc.perform(get("/pg/v1/payments/" + UUID.randomUUID())).andExpect(status().isNotFound());
    }
}
