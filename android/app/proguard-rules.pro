# Razorpay SDK Rules
-keep class com.razorpay.** { *; }

# Google Pay Classes
-keep class com.google.android.apps.nbu.paisa.inapp.client.api.** { *; }
-keep class com.google.android.apps.nbu.paisa.inapp.client.api.Wallet { *; }
-keep class com.google.android.apps.nbu.paisa.inapp.client.api.WalletUtils { *; }

# Suppress Warnings for Google Pay APIs
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.PaymentsClient
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.Wallet
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.WalletUtils

# Preserve ProGuard Annotations
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }
-keep @proguard.annotation.Keep class * { *; }
-keep @proguard.annotation.KeepClassMembers class * { *; }
-dontwarn proguard.annotation.Keep
-dontwarn proguard.annotation.KeepClassMembers

# General Android Rules
-dontwarn android.support.v4.**
-dontwarn androidx.**
-dontwarn com.google.android.gms.**
