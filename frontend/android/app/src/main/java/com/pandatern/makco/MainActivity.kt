package com.pandatern.makco

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.pandatern.makco.data.local.TokenManager
import com.pandatern.makco.ui.screens.AuthScreen
import com.pandatern.makco.ui.screens.HomeScreen
import com.pandatern.makco.ui.theme.Terminal

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val tokens = TokenManager(this)
        setContent {
            var token by remember { mutableStateOf(tokens.token) }
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize(), color = Terminal.Black) {
                    if (token.isNullOrEmpty()) {
                        AuthScreen(
                            onAuthed = { newToken ->
                                tokens.token = newToken
                                token = newToken
                            },
                        )
                    } else {
                        HomeScreen(token = token!!, onLogout = {
                            tokens.clear()
                            token = null
                        })
                    }
                }
            }
        }
    }
}