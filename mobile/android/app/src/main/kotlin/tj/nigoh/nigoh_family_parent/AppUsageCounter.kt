// Файл: ҳисоби дақиқи вақти foreground барои лимити рӯзонаи барнома.

package tj.nigoh.nigoh_family_parent

/** Сонияҳои сабтшуда ва session-и фаъолро бе wall-clock якҷо мекунад. */
internal object AppUsageCounter {
    /** Миллисонияҳои воқеан истифодашударо бармегардонад. */
    fun totalMillis(
        storedSeconds: Long,
        activePersistedSeconds: Long,
        activeSessionStartedAt: Long,
        nowElapsedRealtime: Long,
        isActive: Boolean,
    ): Long {
        var totalSeconds = storedSeconds.coerceAtLeast(0L)
        if (isActive && activeSessionStartedAt > 0L) {
            val elapsedSeconds = ((nowElapsedRealtime - activeSessionStartedAt) / 1000L)
                .coerceAtLeast(0L)
            totalSeconds = maxOf(
                totalSeconds,
                activePersistedSeconds.coerceAtLeast(0L) + elapsedSeconds,
            )
        }
        return totalSeconds.coerceAtMost(Long.MAX_VALUE / 1000L) * 1000L
    }
}
