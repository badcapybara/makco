package com.pandatern.makco.data.remote

import com.pandatern.makco.data.model.*
import okhttp3.OkHttpClient
import retrofit2.Response
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.*
import java.util.concurrent.TimeUnit

interface MakcoApi {

    @POST("auth")
    suspend fun initiateAuth(@Body request: AuthRequest): Response<AuthResponse>

    @POST("auth/{authId}/verify")
    suspend fun verifyAuth(
        @Path("authId") authId: String,
        @Body request: VerifyRequest,
    ): Response<VerifyResponse>

    @GET("transit/stations")
    suspend fun getStations(
        @Header("token") token: String,
        @Query("city") city: String = "chennai",
        @Query("mode") mode: String,
    ): Response<List<Station>>

    @GET("transit/routes")
    suspend fun getRoutes(
        @Header("token") token: String,
        @Query("city") city: String = "chennai",
        @Query("mode") mode: String,
    ): Response<List<RouteInfo>>

    @GET("transit/routes/active")
    suspend fun getActiveRoutes(
        @Header("token") token: String,
        @Query("city") city: String = "chennai",
    ): Response<List<RouteInfo>>

    @GET("transit/route/{routeCode}/stops")
    suspend fun getRouteStops(
        @Header("token") token: String,
        @Path("routeCode") routeCode: String,
        @Query("city") city: String = "chennai",
    ): Response<List<Station>>

    @POST("transit/search")
    suspend fun searchFare(
        @Header("token") token: String,
        @Query("city") city: String = "chennai",
        @Query("mode") mode: String,
        @Body request: SearchRequest,
    ): Response<SearchResponse>

    @GET("transit/search/{searchId}/quote")
    suspend fun getQuote(
        @Header("token") token: String,
        @Path("searchId") searchId: String,
        @Query("city") city: String = "chennai",
        @Query("mode") mode: String,
    ): Response<List<Quote>>

    @POST("transit/quote/{quoteId}/confirm")
    suspend fun confirmBooking(
        @Header("token") token: String,
        @Path("quoteId") quoteId: String,
        @Query("city") city: String = "chennai",
        @Query("mode") mode: String,
        @Body request: ConfirmRequest = ConfirmRequest(),
    ): Response<Booking>

    @GET("transit/booking/{bookingId}/status")
    suspend fun getBookingStatus(
        @Header("token") token: String,
        @Path("bookingId") bookingId: String,
        @Query("city") city: String = "chennai",
        @Query("mode") mode: String,
    ): Response<Booking>

    @GET("transit/booking/{bookingId}/refresh")
    suspend fun refreshBookingStatus(
        @Header("token") token: String,
        @Path("bookingId") bookingId: String,
        @Query("city") city: String = "chennai",
        @Query("mode") mode: String,
    ): Response<Booking>

    @GET("transit/ticket/verify")
    suspend fun verifyTicket(
        @Header("token") token: String,
        @Query("city") city: String = "chennai",
        @Query("mode") mode: String,
        @Query("ticketRef") ticketRef: String,
    ): Response<Map<String, Any>>

    @GET("profile")
    suspend fun getProfile(@Header("token") token: String): Response<Profile>

    @GET("tickets")
    suspend fun getTickets(
        @Header("token") token: String,
        @Query("city") city: String = "chennai",
        @Query("mode") mode: String,
    ): Response<List<Booking>>
}

object ApiClient {
    private const val BASE_URL = "http://10.0.2.2:8080/"

    private val okHttp = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(12, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .build()

    val instance: MakcoApi by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(okHttp)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(MakcoApi::class.java)
    }
}