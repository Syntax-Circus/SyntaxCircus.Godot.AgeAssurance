package com.syntaxcircus.ageassurance

import org.junit.Assert.*
import org.junit.Test

class RequestStateTest {
    @Test fun cancelledAccessCallbackCannotChangeNewerSharingState() {
        val state = RequestState()
        state.begin(1); state.cancel(1)
        state.begin(2)
        assertTrue(state.updateShared(2, true))
        assertFalse(state.updateShared(1, false))
        assertTrue(state.wasShared())
    }
    @Test fun cancelledOrSupersededResultsAreNeverDelivered() {
        val state = RequestState()
        state.begin(1); state.begin(2)
        state.complete(1, "stale")
        assertEquals("", state.take(2))
        state.complete(2, "current")
        state.cancel(1)
        assertEquals("current", state.take(2))
        state.cancel(2)
        state.complete(2, "late")
        assertEquals("", state.take(2))
    }
}
