// Файл: нигоҳдорӣ ва санҷиши PIN-и волидайн бо SHA-256 ва Android Keystore;
// баъди се кӯшиши нодуруст воридшавиро муваққатан мебандад.

package tj.nigoh.nigoh_family_parent

import android.content.Context
import android.util.Base64
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/** PIN-и волидайнро бехатар нигоҳ медорад ва кӯшишҳои воридшавиро назорат мекунад. */
object PinSecurity {
    const val PREFS_NAME = "nigoh_security"

    private const val KEY_ALIAS = "nigoh_family_pin_key"
    private const val RECORD_KEY = "encrypted_pin_record"
    private const val LEGACY_HASH_KEY = "pin_hash"
    private const val LEGACY_SALT_KEY = "pin_salt"
    private const val FAILED_ATTEMPTS_KEY = "pin_failed_attempts"
    private const val LOCKED_UNTIL_KEY = "pin_locked_until"
    private const val LOCKOUT_MS = 30_000L
    private const val MAX_ATTEMPTS = 3
    private const val TRANSFORMATION = "AES/GCM/NoPadding"

    /**
     * Натиҷаи санҷиши PIN: иҷозат, сабаби рад ва сонияҳои боқимондаи басташавӣ.
     */
    data class Result(
        val allowed: Boolean,
        val error: String? = null,
        val remainingSeconds: Long = 0L,
    )

    /** Мавҷуд будани PIN-и волидайнро дар формати ҷорӣ ё кӯҳна месанҷад. */
    fun hasPin(context: Context): Boolean = context.getSharedPreferences(
        PREFS_NAME,
        Context.MODE_PRIVATE,
    ).let { it.contains(RECORD_KEY) || it.contains(LEGACY_HASH_KEY) }

    /**
     * PIN-и нави чоррақамаро санҷида, рамзгузорӣ ва нигоҳ медорад;
     * сабти кӯҳна ва ҳисобкунаки хаторо пок мекунад.
     */
    fun savePin(context: Context, pin: String): Boolean {
        if (!Regex("^\\d{4}$").matches(pin)) return false
        val saltBytes = ByteArray(24).also { SecureRandom().nextBytes(it) }
        val salt = Base64.encodeToString(saltBytes, Base64.NO_WRAP)
        val hash = hashPin(pin, salt)
        val record = "$salt:$hash"
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return runCatching {
            prefs.edit()
                .putString(RECORD_KEY, encrypt(record))
                .remove(LEGACY_HASH_KEY)
                .remove(LEGACY_SALT_KEY)
                .remove(FAILED_ATTEMPTS_KEY)
                .remove(LOCKED_UNTIL_KEY)
                .apply()
            true
        }.getOrDefault(false)
    }

    /**
     * [pin]-ро бо сабти нигоҳдошта муқоиса карда, хатогиҳо ва муҳлати бастаро ҳисоб мекунад.
     */
    fun verify(context: Context, pin: String): Result {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val lockedUntil = prefs.getLong(LOCKED_UNTIL_KEY, 0L)
        if (lockedUntil > now) {
            return Result(
                allowed = false,
                error = "locked",
                remainingSeconds = ((lockedUntil - now + 999L) / 1000L),
            )
        }
        if (!Regex("^\\d{4}$").matches(pin)) return recordFailure(prefs)

        val valid = runCatching {
            val record = prefs.getString(RECORD_KEY, null)?.let(::decrypt)
            if (record != null) {
                val separator = record.indexOf(':')
                if (separator <= 0) false else {
                    val salt = record.substring(0, separator)
                    val expected = record.substring(separator + 1)
                    constantTimeEquals(hashPin(pin, salt), expected)
                }
            } else {
                val salt = prefs.getString(LEGACY_SALT_KEY, null)
                val expected = prefs.getString(LEGACY_HASH_KEY, null)
                salt != null && expected != null && constantTimeEquals(hashPin(pin, salt), expected)
            }
        }.getOrDefault(false)

        if (valid) {
            prefs.edit().remove(FAILED_ATTEMPTS_KEY).remove(LOCKED_UNTIL_KEY).apply()
            return Result(true)
        }
        return recordFailure(prefs)
    }

    /** Хаторо сабт карда, пас аз кӯшиши сеюм PIN-ро 30 сония мебандад. */
    private fun recordFailure(prefs: android.content.SharedPreferences): Result {
        val attempts = prefs.getInt(FAILED_ATTEMPTS_KEY, 0) + 1
        return if (attempts >= MAX_ATTEMPTS) {
            val lockedUntil = System.currentTimeMillis() + LOCKOUT_MS
            prefs.edit()
                .putInt(FAILED_ATTEMPTS_KEY, 0)
                .putLong(LOCKED_UNTIL_KEY, lockedUntil)
                .apply()
            Result(false, "locked", LOCKOUT_MS / 1000L)
        } else {
            prefs.edit().putInt(FAILED_ATTEMPTS_KEY, attempts).apply()
            Result(false, "wrong_pin")
        }
    }

    /** Хэши PIN-ро бо salt ва SHA-256 сохта, ба Base64 мегузаронад. */
    private fun hashPin(pin: String, salt: String): String = Base64.encodeToString(
        MessageDigest.getInstance("SHA-256")
            .digest("$salt:$pin".toByteArray(StandardCharsets.UTF_8)),
        Base64.NO_WRAP,
    )

    /** Ду хэшро бо вақти доимӣ, бе ифшои timing, муқоиса мекунад. */
    private fun constantTimeEquals(left: String, right: String): Boolean =
        MessageDigest.isEqual(
            left.toByteArray(StandardCharsets.UTF_8),
            right.toByteArray(StandardCharsets.UTF_8),
        )

    /** Калиди AES-GCM-ро аз Android Keystore мехонад ё месозад. */
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance("AES", "AndroidKeyStore")
        generator.init(
            android.security.keystore.KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                android.security.keystore.KeyProperties.PURPOSE_ENCRYPT or
                    android.security.keystore.KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(android.security.keystore.KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(android.security.keystore.KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    /** [value]-ро бо калиди Keystore рамзгузорӣ карда, Base64(iv + ciphertext) медиҳад. */
    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val iv = cipher.iv
        val ciphertext = cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8))
        return Base64.encodeToString(iv + ciphertext, Base64.NO_WRAP)
    }

    /** Қимати сохтаи [encrypt]-ро мекушояд; ҳангоми хато null медиҳад. */
    private fun decrypt(value: String): String? = runCatching {
        val encoded = Base64.decode(value, Base64.NO_WRAP)
        val iv = encoded.copyOfRange(0, 12)
        val ciphertext = encoded.copyOfRange(12, encoded.size)
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv))
        String(cipher.doFinal(ciphertext), StandardCharsets.UTF_8)
    }.getOrNull()
}
