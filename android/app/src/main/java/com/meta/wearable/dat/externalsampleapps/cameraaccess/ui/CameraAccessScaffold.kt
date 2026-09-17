package com.meta.wearable.dat.externalsampleapps.cameraaccess.ui

import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionStatus
import com.meta.wearable.dat.externalsampleapps.cameraaccess.wearables.WearablesViewModel

@Composable
fun CameraAccessScaffold(
    viewModel: WearablesViewModel,
    onRequestWearablesPermission: suspend (Permission) -> PermissionStatus,
    modifier: Modifier = Modifier,
) {
    val uiState by viewModel.uiState.collectAsState()
    val activity = LocalActivity.current

    LaunchedEffect(Unit) {
        viewModel.startMonitoring()
    }

    Surface(modifier = modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Box(modifier = Modifier.fillMaxSize()) {
            if (uiState.isSettingsVisible) {
                SettingsScreen(onBack = { viewModel.hideSettings() })
            } else {
                JarvisScreen(
                    isRegistered = uiState.isRegistered,
                    hasActiveDevice = uiState.hasActiveDevice,
                    onOpenSettings = { viewModel.showSettings() },
                    onConnectGlasses = {
                        activity?.let { viewModel.startRegistration(it) }
                    },
                )
            }
        }
    }
}
