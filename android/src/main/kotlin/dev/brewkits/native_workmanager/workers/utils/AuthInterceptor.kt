package dev.brewkits.native_workmanager.workers.utils

import okhttp3.Interceptor
import okhttp3.Response

/**
 * OkHttp interceptor that adds an Authorization header to every request.
 *
 * The header value is produced by substituting `{accessToken}` in [headerTemplate]
 * with the supplied [accessToken]. The default template produces a standard
 * `Authorization: Bearer <token>` header.
 *
 * Example:
 * ```kotlin
 * AuthInterceptor(token)                              // → "Bearer <token>"
 * AuthInterceptor(token, "Token {accessToken}")       // → "Token <token>"
 * AuthInterceptor(token, "ApiKey={accessToken}")      // → "ApiKey=<token>"
 * ```
 */
class AuthInterceptor(
    private val accessToken: String,
    private val headerTemplate: String = "Bearer {accessToken}"
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val headerValue = headerTemplate.replace("{accessToken}", accessToken)
        val request = chain.request().newBuilder()
            .addHeader("Authorization", headerValue)
            .build()
        return chain.proceed(request)
    }
}
