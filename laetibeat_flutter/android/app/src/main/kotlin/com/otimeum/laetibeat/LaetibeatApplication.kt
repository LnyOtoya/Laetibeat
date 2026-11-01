package com.otimeum.laetibeat

import android.app.Application
import android.content.Context

class LaetibeatApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        initRustls(this)
    }

    private external fun initRustls(context: Context)

    private companion object {
        init {
            System.loadLibrary("rust_lib_laetibeat")
        }
    }
}
