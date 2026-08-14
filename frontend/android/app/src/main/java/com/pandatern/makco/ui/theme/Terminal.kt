package com.pandatern.makco.ui.theme

import androidx.compose.ui.graphics.Color

// Rail Signage / Data Terminal palette
object Terminal {
    val Black = Color(0xFF0A0A0A)
    val Panel = Color(0xFF151515)
    val PanelLift = Color(0xFF1D1D1D)
    val Amber = Color(0xFFFFB000)
    val AmberDim = Color(0xFF8A6A00)
    val Green = Color(0xFF00E08A)
    val Red = Color(0xFFFF4D4D)
    val Cyan = Color(0xFF00E0E0)
    val White = Color(0xFFF2F2F2)
    val Dim = Color(0xFF6E6E6E)
    val Hairline = Color(0xFF2A2A2A)
    val FlapBg = Color(0xFF191919)
}

enum class TransitMode(val key: String, val label: String) {
    Metro("metro", "METRO"),
    Bus("bus", "BUS");

    companion object {
        fun from(key: String): TransitMode = entries.firstOrNull { it.key == key } ?: Metro
    }
}