package com.pandatern.makco.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.TextUnitType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.pandatern.makco.data.model.AuthRequest
import com.pandatern.makco.data.model.VerifyRequest
import com.pandatern.makco.data.remote.ApiClient
import com.pandatern.makco.ui.components.*
import com.pandatern.makco.ui.theme.Terminal
import kotlinx.coroutines.launch

@Composable
fun AuthScreen(onAuthed: (String) -> Unit) {
    var phone by remember { mutableStateOf("") }
    var otp by remember { mutableStateOf("") }
    var authId by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    fun requestOtp() {
        if (phone.length != 10) {
            error = "INVALID PHONE. 10 DIGITS"
            return
        }
        busy = true
        error = null
        scope.launch {
            try {
                val resp = ApiClient.instance.initiateAuth(AuthRequest(mobileNumber = phone))
                val id = resp.body()?.authId
                if (resp.isSuccessful && id != null) {
                    authId = id
                } else {
                    error = "AUTH FAILED"
                }
            } catch (e: Exception) {
                error = "NETWORK ERROR"
            }
            busy = false
        }
    }

    fun verify() {
        if (otp.length != 4) {
            error = "OTP MUST BE 4 DIGITS"
            return
        }
        busy = true
        error = null
        scope.launch {
            try {
                val resp = ApiClient.instance.verifyAuth(authId!!, VerifyRequest(otp = otp))
                val token = resp.body()?.token
                if (resp.isSuccessful && token != null) {
                    onAuthed(token)
                } else {
                    error = "INVALID OTP"
                }
            } catch (e: Exception) {
                error = "VERIFY ERROR"
            }
            busy = false
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
    ) {
        Spacer(Modifier.height(24.dp))
        LiveIndicator("AUTH GATEWAY OPEN")
        Spacer(Modifier.height(16.dp))
        SignHeader("OPERATOR AUTH")
        Spacer(Modifier.height(24.dp))
        TerminalPanel {
            Column {
                TerminalText("ENTER MOBILE NUMBER", 11, Terminal.Dim, spacing = 1.5f)
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = phone,
                    onValueChange = { if (it.length <= 10) phone = it },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    singleLine = true,
                    textStyle = TextStyle(
                        fontFamily = Mono,
                        fontSize = 20.sp,
                        color = Terminal.Amber,
                        fontWeight = FontWeight.Bold,
                    ),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Terminal.Amber,
                        unfocusedBorderColor = Terminal.Hairline,
                    ),
                )
                Spacer(Modifier.height(12.dp))
                TermButton(
                    label = if (authId == null) "REQUEST OTP" else "RESEND OTP",
                    onClick = { requestOtp() },
                )
                if (authId != null) {
                    Spacer(Modifier.height(20.dp))
                    TerminalText("ENTER 4-DIGIT OTP", 11, Terminal.Dim, spacing = 1.5f)
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(
                        value = otp,
                        onValueChange = { if (it.length <= 4) otp = it },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        singleLine = true,
                        textStyle = TextStyle(
                            fontFamily = Mono,
                            fontSize = 24.sp,
                            color = Terminal.Amber,
                            fontWeight = FontWeight.Bold,
                        ),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = Terminal.Amber,
                            unfocusedBorderColor = Terminal.Hairline,
                        ),
                    )
                    Spacer(Modifier.height(12.dp))
                    TermButton(
                        label = if (busy) "VERIFYING..." else "VERIFY & CONNECT",
                        color = Terminal.Green,
                        onClick = { verify() },
                    )
                }
                error?.let {
                    Spacer(Modifier.height(16.dp))
                    TerminalText("!! $it", 13, Terminal.Red, FontWeight.Bold)
                }
            }
        }
        Spacer(Modifier.height(24.dp))
        TerminalText(
            "SECURE CHANNEL: MOVINGTECH >> JUSPAY\nTOKEN: PERSISTENT SESSION",
            11,
            Terminal.Dim,
        )
    }
}