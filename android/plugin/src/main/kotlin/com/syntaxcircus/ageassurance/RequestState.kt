package com.syntaxcircus.ageassurance

/** Bounded, thread-safe request state shared by the Godot and Android UI threads. */
internal class RequestState {
    private var active = 0
    private var answer = ""
    private var shared = false
    @Synchronized fun begin(request: Int) { active = request; answer = "" }
    @Synchronized fun isActive(request: Int) = active == request
    @Synchronized fun wasShared() = shared
    @Synchronized fun updateShared(request: Int, value: Boolean): Boolean {
        if (active != request) return false
        shared = value
        return true
    }
    @Synchronized fun complete(request: Int, value: String) { if (active == request) answer = value }
    @Synchronized fun take(request: Int): String =
        if (active != request) "" else answer.also { answer = "" }
    @Synchronized fun cancel(request: Int) { if (active == request) { active = 0; answer = "" } }
}
