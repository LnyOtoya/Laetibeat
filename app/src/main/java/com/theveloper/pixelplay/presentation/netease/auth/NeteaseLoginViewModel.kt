package com.theveloper.pixelplay.presentation.netease.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.theveloper.pixelplay.data.netease.NeteaseRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * Simple ViewModel for WebView-based Netease login.
 * The WebView handles the actual login, this just processes the cookies result.
 */
sealed class NeteaseLoginState {
    object Idle : NeteaseLoginState()
    object Loading : NeteaseLoginState()
    data class Success(val nickname: String) : NeteaseLoginState()
    data class Error(val message: String) : NeteaseLoginState()
}

@HiltViewModel
class NeteaseLoginViewModel @Inject constructor(
    private val repository: NeteaseRepository
) : ViewModel() {

    private val _state = MutableStateFlow<NeteaseLoginState>(NeteaseLoginState.Idle)
    val state: StateFlow<NeteaseLoginState> = _state.asStateFlow()

    /**
     * Process cookies captured from the WebView login.
     * Saves them and fetches user info.
     */
    fun processCookies(cookieJson: String) {
        _state.value = NeteaseLoginState.Loading
        viewModelScope.launch {
            val result = repository.loginWithCookies(cookieJson)
            result.fold(
                onSuccess = { nickname ->
                    _state.value = NeteaseLoginState.Success(nickname)
                },
                onFailure = { error ->
                    _state.value = NeteaseLoginState.Error(error.message ?: "Login failed")
                }
            )
        }
    }
}
