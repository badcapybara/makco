package com.pandatern.makco.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ConfirmationNumber
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.ReceiptLong
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.pandatern.makco.data.model.Booking
import com.pandatern.makco.data.model.Profile
import com.pandatern.makco.data.remote.ApiClient
import com.pandatern.makco.ui.components.*
import com.pandatern.makco.ui.screens.booking.BookingScreen
import com.pandatern.makco.ui.theme.Terminal
import com.pandatern.makco.ui.theme.TransitMode

@Composable
fun HomeScreen(token: String, onLogout: () -> Unit) {
    var tab by remember { mutableStateOf(0) }
    var mode by remember { mutableStateOf(TransitMode.Metro) }
    var booking by remember { mutableStateOf(false) }

    if (booking) {
        BookingScreen(token = token, mode = mode)
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Terminal.Black),
    ) {
        when (tab) {
            0 -> HomeTab(token, mode, onModeChange = { mode = it }, onBook = { booking = true })
            1 -> HistoryScreen(token, mode)
            2 -> ProfileScreen(token, onLogout)
        }
        BottomNav(tab, onTab = { tab = it })
    }
}

@Composable
private fun BottomNav(tab: Int, onTab: (Int) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(Terminal.Panel)
            .border(1.dp, Terminal.Hairline),
    ) {
        NavItem(0, tab, "BOOK", Icons.Outlined.ConfirmationNumber, Modifier.weight(1f)) { onTab(it) }
        NavItem(1, tab, "HISTORY", Icons.Outlined.ReceiptLong, Modifier.weight(1f)) { onTab(it) }
        NavItem(2, tab, "OP", Icons.Outlined.Person, Modifier.weight(1f)) { onTab(it) }
    }
}

@Composable
private fun NavItem(index: Int, current: Int, label: String, icon: ImageVector, modifier: Modifier, onTap: (Int) -> Unit) {
    val selected = index == current
    Column(
        modifier = modifier
            .clickable { onTap(index) }
            .padding(vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = if (selected) Terminal.Amber else Terminal.Dim,
        )
        Spacer(Modifier.height(4.dp))
        TerminalText(label, 10, if (selected) Terminal.Amber else Terminal.Dim, spacing = 1.5f)
    }
}

@Composable
private fun HomeTab(
    token: String,
    mode: TransitMode,
    onModeChange: (TransitMode) -> Unit,
    onBook: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
    ) {
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            LiveIndicator("CHENNAI")
            Spacer(Modifier.weight(1f))
            TerminalText("MAKCO v3.0", 11, Terminal.Dim, spacing = 1.5f)
        }
        Spacer(Modifier.height(8.dp))
        SignHeader("TRANSIT TERMINAL")
        Spacer(Modifier.height(16.dp))
        Row {
            TransitMode.entries.forEach { m ->
                ModeChip(m, selected = m == mode) { onModeChange(m) }
                Spacer(Modifier.width(10.dp))
            }
        }
        Spacer(Modifier.height(20.dp))
        Row {
            TerminalText("MODE:", 12, Terminal.Dim, spacing = 2f)
            Spacer(Modifier.width(8.dp))
            TerminalText(mode.label, 20, Terminal.Amber, androidx.compose.ui.text.font.FontWeight.Bold, spacing = 2f)
        }
        Spacer(Modifier.height(16.dp))
        TerminalPanel(borderColor = Terminal.Amber) {
            Column {
                TerminalText("NEXT DEPARTURE BOARD", 11, Terminal.Green, spacing = 2f)
                Spacer(Modifier.height(12.dp))
                DepartureRow("ROUTE", "SELECT TO PROCEED", color = Terminal.Dim, flapWidth = 200)
                Spacer(Modifier.height(16.dp))
                TermButton(
                    label = "BOOK ${mode.label} TICKET",
                    onClick = onBook,
                )
            }
        }
        Spacer(Modifier.height(20.dp))
        TerminalText("SYSTEM", 12, Terminal.Dim, spacing = 2f)
        Spacer(Modifier.height(8.dp))
        TerminalPanel(borderColor = Terminal.Hairline) {
            Column {
                DepartureRow("TRANSIT", "BUS + METRO", color = Terminal.Cyan, flapWidth = 160)
                DepartureRow("PAYMENT", "JUSPAY", color = Terminal.Cyan, flapWidth = 160)
            }
        }
        Spacer(Modifier.height(20.dp))
        TermButton(
            label = "OPEN BOOKING ${mode.label}",
            color = Terminal.Green,
            onClick = onBook,
        )
    }
}

@Composable
private fun ModeChip(m: TransitMode, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clickable(onClick = onClick)
            .background(if (selected) Terminal.Amber else Terminal.Panel)
            .border(2.dp, if (selected) Terminal.Amber else Terminal.Hairline)
            .padding(horizontal = 18.dp, vertical = 10.dp),
    ) {
        TerminalText(
            m.label,
            14,
            if (selected) Terminal.Black else Terminal.White,
            androidx.compose.ui.text.font.FontWeight.Bold,
            spacing = 2f,
        )
    }
}

@Composable
fun HistoryScreen(token: String, mode: TransitMode) {
    var bookings by remember { mutableStateOf(emptyList<Booking>()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(mode) {
        loading = true
        error = null
        try {
            val resp = ApiClient.instance.getTickets(token, mode = mode.key)
            if (resp.isSuccessful) {
                bookings = resp.body() ?: emptyList()
            } else {
                error = "HISTORY FEED OFFLINE"
            }
        } catch (e: Exception) {
            error = "HISTORY FEED OFFLINE"
        }
        loading = false
    }

    Column(Modifier.fillMaxSize()) {
        LiveIndicator("BOOKING ARCHIVE", Modifier.padding(16.dp, 12.dp, 16.dp, 0.dp))
        Spacer(Modifier.height(8.dp))
        SignHeader("TRANSIT HISTORY")
        Spacer(Modifier.height(16.dp))
        when {
            loading -> CenterText("LOADING ARCHIVE...", Terminal.Green)
            error != null -> CenterText("!! $error", Terminal.Red)
            bookings.isEmpty() -> CenterText("NO BOOKINGS ON RECORD", Terminal.Dim)
            else -> LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(bookings) { b ->
                    TerminalPanel(borderColor = statusColor(b.status)) {
                        Row {
                            TerminalText(b.status, 13, statusColor(b.status), androidx.compose.ui.text.font.FontWeight.Bold, spacing = 1.5f)
                            Spacer(Modifier.weight(1f))
                            TerminalText("₹${b.price}", 18, Terminal.Amber, androidx.compose.ui.text.font.FontWeight.Bold)
                        }
                        Spacer(Modifier.height(6.dp))
                        TerminalText("${mode.label} // ${b.bookingId.take(10)}...", 11, Terminal.Dim)
                    }
                }
            }
        }
    }
}

private fun statusColor(status: String) = when (status) {
    "CONFIRMED" -> Terminal.Green
    "CANCELLED" -> Terminal.Red
    else -> Terminal.Amber
}

@Composable
private fun CenterText(text: String, color: Color) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        TerminalText(text, 13, color)
    }
}

@Composable
fun ProfileScreen(token: String, onLogout: () -> Unit) {
    var profile by remember { mutableStateOf<Profile?>(null) }

    LaunchedEffect(Unit) {
        try {
            val resp = ApiClient.instance.getProfile(token)
            if (resp.isSuccessful) profile = resp.body()
        } catch (_: Exception) {}
    }

    Column(Modifier.fillMaxSize()) {
        LiveIndicator("OPERATOR IDENTITY", Modifier.padding(16.dp, 12.dp, 16.dp, 0.dp))
        Spacer(Modifier.height(8.dp))
        SignHeader("OPERATOR PROFILE")
        Spacer(Modifier.height(20.dp))
        if (profile == null) {
            CenterText("READING IDENTITY...", Terminal.Green)
        } else {
            val p = profile!!
            Column(Modifier.padding(16.dp)) {
                TerminalPanel(borderColor = Terminal.Amber) {
                    Column {
                        TerminalText("ID", 11, Terminal.Dim, spacing = 2f)
                        Spacer(Modifier.height(4.dp))
                        TerminalText(p.id, 13, Terminal.White)
                        Spacer(Modifier.height(14.dp))
                        TerminalText("MASKED NUMBER", 11, Terminal.Dim, spacing = 2f)
                        Spacer(Modifier.height(4.dp))
                        TerminalText(p.maskedMobile, 18, Terminal.Amber, androidx.compose.ui.text.font.FontWeight.Bold)
                        Spacer(Modifier.height(14.dp))
                        TerminalText("GENDER", 11, Terminal.Dim, spacing = 2f)
                        Spacer(Modifier.height(4.dp))
                        TerminalText(p.gender, 13, Terminal.White)
                    }
                }
                Spacer(Modifier.height(24.dp))
                TermButton("TERMINATE SESSION", color = Terminal.Red, onClick = onLogout)
            }
        }
    }
}