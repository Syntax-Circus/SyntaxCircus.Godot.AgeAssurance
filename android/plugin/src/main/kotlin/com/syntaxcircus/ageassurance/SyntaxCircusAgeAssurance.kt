package com.syntaxcircus.ageassurance

import com.google.android.play.agesignals.AgeSignalsAccessRequest
import com.google.android.play.agesignals.AgeSignalsManagerFactory
import com.google.android.play.agesignals.AgeSignalsRequest
import com.google.android.play.agesignals.model.AgeSignalsStatus
import com.google.android.play.agesignals.model.SignificantChangeStatus
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject

/** Explicit requests only; bounded mailbox. No identifiers, logs, files or startup SDK calls. */
class SyntaxCircusAgeAssurance(godot: Godot) : GodotPlugin(godot) {
    private val state = RequestState()
    override fun getPluginName() = "SyntaxCircusAgeAssurance"

    private fun complete(request: Int, value: JSONObject) = state.complete(request,value.toString())
    @UsedByGodot fun cancel_check(request: Int) = state.cancel(request)
    @UsedByGodot fun take_result(request: Int): String = state.take(request)
    @UsedByGodot fun request_check(request: Int, minimum: Int, allowPrompt: Boolean) {
        state.begin(request)
        val activity = activity
        if (activity == null || minimum !in 1..120) {
            complete(request, JSONObject().put("status", "unavailable")); return
        }
        activity.runOnUiThread {
            if (!state.isActive(request)) return@runOnUiThread
            val manager = AgeSignalsManagerFactory.create(activity.applicationContext)
            fun retrieve() {
                if (!state.isActive(request)) return
                manager.checkAgeSignals(AgeSignalsRequest.builder().build())
                    .addOnSuccessListener { result ->
                        val wire = JSONObject().put("status", "shared")
                        // Silent range queries do not expose sharing/verification status. If a
                        // formerly shared range disappears, require an explicit access recheck
                        // rather than assuming it is optional (or falsely claiming underage).
                        if (!allowPrompt && result.ageLower() == null && result.ageUpper() == null) {
                            wire.put("status", "recheck_required")
                        }
                        result.ageLower()?.let { wire.put("lower", it) }
                        // Play upper bound is inclusive; the common contract uses an exclusive bound.
                        result.ageUpper()?.let { wire.put("upper_exclusive", it + 1) }
                        when (result.significantChangeStatus()) {
                            SignificantChangeStatus.PENDING -> wire.put("approval", "pending")
                            SignificantChangeStatus.DECLINED -> wire.put("approval", "declined")
                            SignificantChangeStatus.APPROVED -> wire.put("approval", "approved")
                        }
                        // Deliberately never read installId() or ageRangeSource().
                        complete(request, wire)
                    }.addOnFailureListener { complete(request, JSONObject().put("status", "unavailable")) }
            }
            if (!allowPrompt) {
                if (state.wasShared()) retrieve() else complete(request, JSONObject().put("status", "unavailable"))
            } else {
                manager.requestAgeSignalsAccess(AgeSignalsAccessRequest.builder().setActivity(activity).build())
                    .addOnSuccessListener { access ->
                        if (!state.updateShared(request, access.ageSignalsStatus() == AgeSignalsStatus.SHARED)) return@addOnSuccessListener
                        when (access.ageSignalsStatus()) {
                            AgeSignalsStatus.SHARED -> retrieve()
                            AgeSignalsStatus.VERIFICATION_REQUIRED -> {
                                complete(request, JSONObject().put("status", "verification_required"))
                            }
                            else -> complete(request, JSONObject().put("status", "declined"))
                        }
                    }.addOnFailureListener { complete(request, JSONObject().put("status", "unavailable")) }
            }
        }
    }
}
