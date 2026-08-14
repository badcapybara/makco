package com.pandatern.makco.ui.screens.payment

import android.annotation.SuppressLint
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.pandatern.makco.data.model.Booking
import com.pandatern.makco.data.remote.ApiClient
import com.pandatern.makco.ui.components.*
import com.pandatern.makco.ui.theme.Terminal
import com.pandatern.makco.ui.theme.TransitMode
import kotlinx.coroutines.delay

@Composable
fun PaymentScreen(
    token: String,
    mode: TransitMode,
    booking: Booking,
    onDone: () -> Unit,
) {
    var current by remember { mutableStateOf(booking) }
    var confirmed by remember { mutableStateOf(false) }

    LaunchedEffect(current.bookingId) {
        while (true) {
            delay(5000)
            try {
                val resp = ApiClient.instance.getBookingStatus(token, current.bookingId, mode = mode.key)
                val b = resp.body()
                if (b != null) {
                    current = b
                    if (b.status == "CONFIRMED" || b.tickets.isNotEmpty()) {
                        confirmed = true
                        onDone()
                        return@LaunchedEffect
                    }
                }
            } catch (_: Exception) {}
        }
    }

    Column(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxWidth().background(Terminal.PanelLift).padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                LiveIndicator("PAYMENT PENDING")
                Spacer(Modifier.weight(1f))
                TerminalText("₹${current.price}", 24, Terminal.Amber, androidx.compose.ui.text.font.FontWeight.Bold)
            }
            Spacer(Modifier.height(6.dp))
            TerminalText("BOOKING ${current.bookingId}", 10, Terminal.Dim)
            TerminalText("STATUS: ${current.status}", 12, Terminal.Cyan, spacing = 1.5f)
        }
        Box(Modifier.weight(1f)) {
            if (confirmed) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    TerminalText("PAYMENT CONFIRMED", 16, Terminal.Green, androidx.compose.ui.text.font.FontWeight.Bold)
                }
            } else if (current.paymentUrl.isNotEmpty()) {
                AndroidView(
                    factory = { ctx ->
                        WebView(ctx).apply {
                            webViewClient = WebViewClient()
                            settings.javaScriptEnabled = true
                            loadUrl(current.paymentUrl)
                        }
                    },
                    update = { it.loadUrl(current.paymentUrl) },
                )
            } else {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        TerminalText("AWAITING PAYMENT ORDER...", 13, Terminal.Green)
                        Spacer(Modifier.height(16.dp))
                        TermButton("REFRESH", onClick = {})
                    }
                }
            }
        }
    }
}