package com.pandatern.makco.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pandatern.makco.ui.theme.Terminal

val Mono: FontFamily = FontFamily.Monospace

@Composable
fun TerminalText(
    text: String,
    size: Int = 14,
    color: Color = Terminal.Amber,
    weight: FontWeight = FontWeight.Normal,
    spacing: Float = 0f,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        fontFamily = Mono,
        fontSize = size.sp,
        color = color,
        fontWeight = weight,
        letterSpacing = spacing.sp,
        modifier = modifier,
    )
}

@Composable
fun SplitFlap(
    text: String,
    width: Int = 64,
    height: Int = 48,
    fontSize: Int = 24,
    color: Color = Terminal.Amber,
    bg: Color = Terminal.FlapBg,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .width(width.dp)
            .height(height.dp)
            .background(bg)
            .border(1.dp, Terminal.Hairline),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height((height / 2).dp)
                .background(Color(0xFF111111)),
            contentAlignment = Alignment.Center,
        ) {
            TerminalText(text, fontSize, color, FontWeight.Bold)
        }
    }
}

@Composable
fun DepartureRow(
    label: String,
    value: String,
    color: Color = Terminal.White,
    flapWidth: Int = 180,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(modifier = Modifier.width(92.dp)) {
            TerminalText(label, 11, Terminal.Dim, spacing = 1.5f)
        }
        SplitFlap(value, width = flapWidth, height = 40, fontSize = 18, color = color)
    }
}

@Composable
fun TerminalPanel(
    modifier: Modifier = Modifier,
    borderColor: Color = Terminal.Amber,
    padding: Int = 16,
    content: @Composable () -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(Terminal.Panel)
            .border(1.dp, borderColor)
            .padding(padding.dp),
    ) {
        content()
    }
}

@Composable
fun LiveIndicator(text: String, modifier: Modifier = Modifier) {
    Row(modifier = modifier, verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .background(Terminal.Green, shape = androidx.compose.foundation.shape.CircleShape),
        )
        Spacer(modifier = Modifier.width(8.dp))
        TerminalText(text, 11, Terminal.Green, spacing = 1.5f)
    }
}

@Composable
fun SignHeader(title: String, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .background(Terminal.Amber)
            .padding(horizontal = 16.dp, vertical = 14.dp),
    ) {
        TerminalText(title.uppercase(), 18, Terminal.Black, FontWeight.Bold, spacing = 2f)
    }
}

@Composable
fun TermButton(
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    filled: Boolean = true,
    color: Color = Terminal.Amber,
    height: Int = 52,
) {
    val fg = if (filled) Terminal.Black else color
    val bg = if (filled) color else Color.Transparent
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height.dp)
            .background(bg)
            .border(2.dp, color)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        TerminalText(label.uppercase(), 15, fg, FontWeight.Bold, spacing = 2f)
    }
}