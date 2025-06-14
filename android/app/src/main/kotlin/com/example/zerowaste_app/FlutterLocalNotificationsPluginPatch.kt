package com.example.zerowaste_app

import android.graphics.Bitmap
import android.app.Notification.BigPictureStyle
import android.graphics.drawable.Icon

object FlutterLocalNotificationsPluginPatch {
    fun setBigLargeIcon(style: BigPictureStyle, bitmap: Bitmap?) {
        style.bigLargeIcon(bitmap as Bitmap?)
    }

    fun setBigLargeIconWithIcon(style: BigPictureStyle, icon: Icon?) {
        style.bigLargeIcon(icon as Icon?)
    }
} 