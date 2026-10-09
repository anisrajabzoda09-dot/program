// Файл: unit-test-ҳои ҳисобкунаки вақти воқеии foreground.

package tj.nigoh.nigoh_family_parent

import org.junit.Assert.assertEquals
import org.junit.Test

class AppUsageCounterTest {
    @Test
    fun reachesOneHourOnlyAfterOneHourOfForegroundUse() {
        assertEquals(
            3_600_000L,
            AppUsageCounter.totalMillis(
                storedSeconds = 3_599L,
                activePersistedSeconds = 3_599L,
                activeSessionStartedAt = 10_000L,
                nowElapsedRealtime = 11_000L,
                isActive = true,
            ),
        )
    }

    @Test
    fun backgroundTimeDoesNotIncreaseUsage() {
        assertEquals(
            900_000L,
            AppUsageCounter.totalMillis(
                storedSeconds = 900L,
                activePersistedSeconds = 900L,
                activeSessionStartedAt = 10_000L,
                nowElapsedRealtime = 3_610_000L,
                isActive = false,
            ),
        )
    }

    @Test
    fun backwardsElapsedClockNeverSubtractsUsage() {
        assertEquals(
            120_000L,
            AppUsageCounter.totalMillis(
                storedSeconds = 120L,
                activePersistedSeconds = 120L,
                activeSessionStartedAt = 20_000L,
                nowElapsedRealtime = 10_000L,
                isActive = true,
            ),
        )
    }
}
