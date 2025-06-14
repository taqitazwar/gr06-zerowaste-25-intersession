package com.example.zerowaste_app

import android.app.Notification.BigPictureStyle
import android.graphics.Bitmap

class CustomNotificationStyle : BigPictureStyle() {
    override fun bigLargeIcon(bm: Bitmap?): BigPictureStyle {
        return super.bigLargeIcon(bm)
    }
} 