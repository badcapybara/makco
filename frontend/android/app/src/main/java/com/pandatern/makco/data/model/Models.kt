package com.pandatern.makco.data.model

import com.google.gson.annotations.SerializedName

data class Station(
    val code: String = "",
    val name: String = "",
    val lat: Double? = null,
    val lon: Double? = null,
)

data class RouteInfo(
    val code: String = "",
    @SerializedName("longName") val longName: String = "",
    @SerializedName("shortName") val shortName: String = "",
)

data class AuthRequest(
    @SerializedName("mobileNumber") val mobileNumber: String,
    @SerializedName("mobileCountryCode") val mobileCountryCode: String = "+91",
    @SerializedName("merchantId") val merchantId: String = "NAMMA_YATRI",
    @SerializedName("clientId") val clientId: String = "NAMMA_YATRI",
)

data class AuthResponse(val authId: String? = null, val attempts: Int? = null)

data class VerifyRequest(val otp: String, @SerializedName("deviceToken") val deviceToken: String = "makco_device")

data class VerifyResponse(val token: String? = null, @SerializedName("userId") val userId: String? = null)

data class SearchRequest(
    @SerializedName("fromStationCode") val fromStationCode: String,
    @SerializedName("toStationCode") val toStationCode: String,
    val quantity: Int = 1,
)

data class SearchResponse(val searchId: String = "")

data class Quote(
    @SerializedName("_type") val type: String = "",
    @SerializedName("quoteId") val quoteId: String = "",
    val price: Double = 0.0,
    val quantity: Int = 1,
    @SerializedName("validTill") val validTill: String = "",
)

data class ConfirmRequest(val quantity: Int = 1)

data class Booking(
    @SerializedName("bookingId") val bookingId: String = "",
    val status: String = "NEW",
    val price: Double = 0.0,
    val payment: Payment? = null,
    val tickets: List<Any> = emptyList(),
) {
    val paymentUrl: String
        get() = payment?.paymentOrder?.paymentLinks?.web ?: ""
}

data class Payment(val paymentOrder: PaymentOrder? = null, val status: String = "NEW")

data class PaymentOrder(val id: String = "", @SerializedName("order_id") val orderId: String = "") {
    @SerializedName("payment_links")
    val paymentLinks: PaymentLinks = PaymentLinks()
}

data class PaymentLinks(val web: String = "")

data class Profile(
    val id: String = "",
    @SerializedName("maskedMobileNumber") val maskedMobile: String = "",
    val gender: String = "UNKNOWN",
)

data class ApiError(val errorCode: String? = null, val errorMessage: String? = null, val error: String? = null)