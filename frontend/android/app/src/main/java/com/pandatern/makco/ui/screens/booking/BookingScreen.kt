package com.pandatern.makco.ui.screens.booking

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.pandatern.makco.data.model.*
import com.pandatern.makco.data.remote.ApiClient
import com.pandatern.makco.ui.components.*
import com.pandatern.makco.ui.theme.Terminal
import com.pandatern.makco.ui.theme.TransitMode
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun BookingScreen(token: String, mode: TransitMode) {
    var stations by remember { mutableStateOf(emptyList<Station>()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var from by remember { mutableStateOf<Station?>(null) }
    var to by remember { mutableStateOf<Station?>(null) }
    var qty by remember { mutableStateOf(1) }
    var quotes by remember { mutableStateOf(emptyList<Quote>()) }
    var searching by remember { mutableStateOf(false) }
    var selected by remember { mutableStateOf<Quote?>(null) }
    var showPicker by remember { mutableStateOf(false) }
    var pickFrom by remember { mutableStateOf(true) }
    var showPayment by remember { mutableStateOf(false) }
    var paymentBooking by remember { mutableStateOf<Booking?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        try {
            val resp = ApiClient.instance.getStations(token, mode = mode.key)
            if (resp.isSuccessful) stations = resp.body() ?: emptyList()
            else error = "STATION FEED OFFLINE"
        } catch (e: Exception) {
            error = "STATION FEED OFFLINE"
        }
        loading = false
    }

    if (showPayment && paymentBooking != null) {
        com.pandatern.makco.ui.screens.payment.PaymentScreen(token, mode, paymentBooking!!, onDone = {})
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Terminal.Black),
    ) {
        SignHeader("${mode.label} // CHENNAI")
        LiveIndicator("FARE TERMINAL", Modifier.padding(16.dp, 12.dp, 16.dp, 0.dp))
        Spacer(Modifier.height(12.dp))
        when {
            loading -> CenterText("LOADING STATIONS...", Terminal.Green)
            error != null && stations.isEmpty() -> Column(Modifier.padding(16.dp)) {
                TerminalText("!! $error", 13, Terminal.Red)
                Spacer(Modifier.height(12.dp))
                TermButton("RETRY FEED", color = Terminal.Red, onClick = {})
            }
            else -> Column {
                TerminalPanel(Modifier.padding(horizontal = 16.dp)) {
                    Column {
                        StationRow("FROM", from) {
                            pickFrom = true
                            showPicker = true
                        }
                        Spacer(Modifier.height(8.dp))
                        StationRow("TO  ", to) {
                            pickFrom = false
                            showPicker = true
                        }
                        Spacer(Modifier.height(16.dp))
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            TerminalText("QTY", 12, Terminal.Dim, spacing = 2f)
                            Spacer(Modifier.width(12.dp))
                            QtyBtn("-") { if (qty > 1) qty-- }
                            Spacer(Modifier.width(10.dp))
                            SplitFlap("$qty", width = 60, height = 44, fontSize = 22)
                            Spacer(Modifier.width(10.dp))
                            QtyBtn("+") { if (qty < 5) qty++ }
                        }
                    }
                }
                Spacer(Modifier.height(16.dp))
                TermButton(
                    label = if (searching) "SEARCHING..." else "SEARCH FARE",
                    modifier = Modifier.padding(horizontal = 16.dp),
                    onClick = {
                        if (from == null || to == null) {
                            error = "SELECT FROM + TO"
                            return@TermButton
                        }
                        searching = true
                        error = null
                        scope.launch {
                            try {
                                val s = ApiClient.instance.searchFare(
                                    token,
                                    mode = mode.key,
                                    request = SearchRequest(from!!.code, to!!.code, qty),
                                )
                                val searchId = s.body()?.searchId.orEmpty()
                                for (i in 0 until 6) {
                                    delay(2000)
                                    val q = ApiClient.instance.getQuote(token, searchId, mode = mode.key)
                                    val list = q.body() ?: emptyList()
                                    if (list.isNotEmpty()) {
                                        quotes = list
                                        break
                                    }
                                }
                            } catch (e: Exception) {
                                error = "SEARCH FAILED"
                            }
                            searching = false
                        }
                    },
                )
                Spacer(Modifier.height(12.dp))
                if (quotes.isNotEmpty()) {
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        items(quotes) { q ->
                            QuoteCard(
                                quote = q,
                                selected = q.quoteId == selected?.quoteId,
                                onSelect = { selected = q },
                                onConfirm = {
                                    scope.launch {
                                        try {
                                            val resp = ApiClient.instance.confirmBooking(
                                                token,
                                                q.quoteId,
                                                mode = mode.key,
                                                request = ConfirmRequest(q.quantity),
                                            )
                                            val booking = resp.body()
                                            if (booking != null) {
                                                paymentBooking = booking
                                                showPayment = true
                                            } else {
                                                error = "CONFIRM FAILED"
                                            }
                                        } catch (e: Exception) {
                                            error = "CONFIRM FAILED"
                                        }
                                    }
                                },
                            )
                        }
                    }
                }
                error?.let {
                    TerminalText("!! $it", 13, Terminal.Red, modifier = Modifier.padding(16.dp))
                }
            }
        }
    }

    if (showPicker) {
        Dialog(onDismissRequest = { showPicker = false }) {
            StationPickerDialog(
                stations = stations,
                onPick = { s ->
                    if (pickFrom) from = s else to = s
                    quotes = emptyList()
                    selected = null
                    showPicker = false
                },
            )
        }
    }
}

@Composable
private fun StationRow(label: String, s: Station?, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .background(Terminal.PanelLift)
            .border(1.dp, Terminal.Hairline)
            .padding(horizontal = 12.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TerminalText(label, 12, Terminal.Dim, spacing = 2f)
        Spacer(Modifier.width(16.dp))
        TerminalText(
            s?.name ?: "-------",
            16,
            if (s != null) Terminal.White else Terminal.Dim,
            androidx.compose.ui.text.font.FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        s?.let { TerminalText(it.code, 12, Terminal.Amber, spacing = 1f) }
    }
}

@Composable
private fun QtyBtn(label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clickable(onClick = onClick)
            .background(Terminal.PanelLift)
            .border(2.dp, Terminal.Amber),
        contentAlignment = Alignment.Center,
    ) {
        TerminalText(label, 20, Terminal.Amber, androidx.compose.ui.text.font.FontWeight.Bold)
    }
}

@Composable
private fun QuoteCard(
    quote: Quote,
    selected: Boolean,
    onSelect: () -> Unit,
    onConfirm: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onSelect)
            .background(if (selected) Terminal.AmberDim.copy(alpha = 0.15f) else Terminal.Panel)
            .border(if (selected) 2.dp else 1.dp, if (selected) Terminal.Amber else Terminal.Hairline)
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TerminalText(quote.type.uppercase(), 13, Terminal.Cyan, spacing = 1.5f)
            Spacer(Modifier.weight(1f))
            TerminalText("₹${quote.price}", 22, Terminal.Amber, androidx.compose.ui.text.font.FontWeight.Bold)
        }
        Spacer(Modifier.height(6.dp))
        TerminalText("VALID TILL ${quote.validTill}", 10, Terminal.Dim)
        if (selected) {
            Spacer(Modifier.height(12.dp))
            TermButton("CONFIRM BOOKING", color = Terminal.Green, onClick = onConfirm)
        }
    }
}

@Composable
private fun CenterText(text: String, color: Color) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        TerminalText(text, 13, color)
    }
}

@Composable
fun StationPickerDialog(
    stations: List<Station>,
    onPick: (Station) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    val filtered = stations.filter {
        it.name.contains(query, ignoreCase = true) || it.code.contains(query, ignoreCase = true)
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Terminal.Panel, shape = RoundedCornerShape(4.dp))
            .border(1.dp, Terminal.Amber, RoundedCornerShape(4.dp)),
    ) {
        SignHeader("SELECT STATION")
        OutlinedTextField(
            value = query,
            onValueChange = { query = it },
            placeholder = { TerminalText("SEARCH STATION / CODE", 12, Terminal.Dim) },
            modifier = Modifier.padding(12.dp),
            textStyle = androidx.compose.ui.text.TextStyle(
                fontFamily = Mono,
                fontSize = androidx.compose.ui.unit.TextUnit(16f, androidx.compose.ui.unit.TextUnitType.Sp),
                color = Terminal.Amber,
            ),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Terminal.Amber,
                unfocusedBorderColor = Terminal.Hairline,
            ),
        )
        LazyColumn(Modifier.height(400.dp)) {
            items(filtered) { s ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onPick(s) }
                        .padding(14.dp),
                ) {
                    TerminalText(s.code, 11, Terminal.Amber, spacing = 1f, modifier = Modifier.width(90.dp))
                    TerminalText(s.name.uppercase(), 14, Terminal.White, androidx.compose.ui.text.font.FontWeight.SemiBold)
                }
            }
        }
    }
}