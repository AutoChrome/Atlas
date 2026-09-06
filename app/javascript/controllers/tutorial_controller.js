import { Controller } from "@hotwired/stimulus"

// Drives the "walk through it" viewing experience: an overview screen
// (description + full step/task outline) shown first, then one step at a
// time behind a Start button. Each task is accepted or rejected (tick/
// cross) rather than just checked off — the step's Continue button uses
// the viewer's own answers to pick the next step, following whichever task
// (in position order) carries a matching next_step_if_accepted/rejected
// rule, falling back to the step's default next step in authoring order.
//
// Responses persist to the server for signed-in users (any role) so they
// follow their account; for anonymous visitors there's no account to
// attach them to, so they live only in this browser's localStorage.
export default class extends Controller {
  static targets = [
    "overview", "progressSection", "step", "finished",
    "progressFill", "progressLabel", "acceptButton", "rejectButton", "manageSteps"
  ]
  static values = { signedIn: Boolean, storageKey: String, totalSteps: Number, responseUrl: String, progressUrl: String }

  connect() {
    if (!this.signedInValue) this.restoreLocalResponses()
    this.updateProgress()
    this.showOverview()
  }

  start() {
    const savedStepId = this.readLocal("current_step")
    const target = savedStepId && this.stepTargets.find((el) => el.dataset.stepId === savedStepId)
    this.showStep(target || this.stepTargets[0])
  }

  // "Start over" — clears every tick/cross plus navigation history, both
  // locally and (for a signed-in viewer) on the server, then drops back to
  // the overview screen as if this were a first visit.
  resetProgress() {
    if (!confirm("Reset all progress on this tutorial? This can't be undone.")) return

    this.clearLocal("current_step")
    this.clearLocal("history")
    this.clearLocal("responses")

    this.acceptButtonTargets.forEach((button) => button.classList.remove("is-active"))
    this.rejectButtonTargets.forEach((button) => button.classList.remove("is-active"))

    if (this.signedInValue) {
      fetch(this.progressUrlValue, {
        method: "DELETE",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
      }).catch(() => {
        // Best-effort — local state is already cleared either way.
      })
    }

    this.updateProgress()
    this.showOverview()
  }

  continue(event) {
    const stepEl = event.target.closest('[data-tutorial-target="step"]')
    const nextStepId = this.resolveNextStep(stepEl)

    this.pushHistory()

    if (!nextStepId) {
      this.showFinished()
      return
    }

    const target = this.stepTargets.find((el) => el.dataset.stepId === nextStepId)
    if (target) this.showStep(target)
  }

  goToPrevious() {
    const history = this.readHistory()
    const previousStepId = history.pop()

    if (previousStepId === undefined) {
      // No recorded history — either this is genuinely the first step (in
      // which case "back" means the overview screen), or a resumed session
      // that never pushed history this visit (fall back to the step before
      // the current one in authoring order).
      this.showPreviousByPosition()
      return
    }

    this.writeHistory(history)
    if (this.hasFinishedTarget) this.finishedTarget.hidden = true
    const target = this.stepTargets.find((el) => el.dataset.stepId === previousStepId)
    if (target) this.showStep(target)
  }

  showPreviousByPosition() {
    const currentStepId = this.readLocal("current_step")
    const currentIndex = this.stepTargets.findIndex((el) => el.dataset.stepId === currentStepId)

    if (currentIndex <= 0) {
      this.showOverview()
      return
    }

    if (this.hasFinishedTarget) this.finishedTarget.hidden = true
    this.showStep(this.stepTargets[currentIndex - 1])
  }

  // The first task (in DOM/position order) that's been decided AND carries
  // a rule matching that decision wins; a task with no decision, or a
  // decision with no rule set for it, is simply skipped over.
  resolveNextStep(stepEl) {
    const rows = Array.from(stepEl.querySelectorAll("[data-task-id]"))

    for (const row of rows) {
      const accepted = this.currentResponseFor(row.dataset.taskId)
      if (accepted === true && row.dataset.nextStepIfAcceptedId) return row.dataset.nextStepIfAcceptedId
      if (accepted === false && row.dataset.nextStepIfRejectedId) return row.dataset.nextStepIfRejectedId
    }

    return stepEl.dataset.defaultNextStepId || null
  }

  showOverview() {
    if (this.hasOverviewTarget) this.overviewTarget.hidden = false
    if (this.hasProgressSectionTarget) this.progressSectionTarget.hidden = true
    this.stepTargets.forEach((el) => (el.hidden = true))
    if (this.hasFinishedTarget) this.finishedTarget.hidden = true
    if (this.hasManageStepsTarget) this.manageStepsTarget.open = true
  }

  showStep(target) {
    if (this.hasOverviewTarget) this.overviewTarget.hidden = true
    if (this.hasProgressSectionTarget) this.progressSectionTarget.hidden = false
    this.stepTargets.forEach((el) => (el.hidden = el !== target))
    if (this.hasFinishedTarget) this.finishedTarget.hidden = true
    if (this.hasManageStepsTarget) this.manageStepsTarget.open = false
    if (target) {
      this.writeLocal("current_step", target.dataset.stepId)
      target.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }

  showFinished() {
    if (this.hasOverviewTarget) this.overviewTarget.hidden = true
    this.stepTargets.forEach((el) => (el.hidden = true))
    if (this.hasFinishedTarget) this.finishedTarget.hidden = false
    if (this.hasManageStepsTarget) this.manageStepsTarget.open = false
  }

  accept(event) {
    this.recordResponse(event.params.taskId, true)
  }

  reject(event) {
    this.recordResponse(event.params.taskId, false)
  }

  recordResponse(taskId, accepted) {
    this.setButtonState(taskId, accepted)

    if (this.signedInValue) {
      fetch(`${this.responseUrlValue}?tutorial_task_id=${taskId}&accepted=${accepted}`, {
        method: "POST",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
      }).catch(() => {
        // Best-effort — the buttons already reflect the intended state.
      })
    } else {
      const responses = this.readLocalResponses()
      responses[taskId] = accepted
      this.writeLocal("responses", JSON.stringify(responses))
    }

    this.updateProgress()
  }

  setButtonState(taskId, accepted) {
    this.acceptButtonTargets
      .filter((button) => button.dataset.taskId === String(taskId))
      .forEach((button) => button.classList.toggle("is-active", accepted === true))
    this.rejectButtonTargets
      .filter((button) => button.dataset.taskId === String(taskId))
      .forEach((button) => button.classList.toggle("is-active", accepted === false))
  }

  // true/false/null (undecided) — read from the buttons' own active state
  // rather than a separate data store, so it always reflects what's on
  // screen right now regardless of how it got there (server-rendered on
  // load, or set client-side just now).
  currentResponseFor(taskId) {
    const acceptButton = this.acceptButtonTargets.find((button) => button.dataset.taskId === String(taskId))
    const rejectButton = this.rejectButtonTargets.find((button) => button.dataset.taskId === String(taskId))

    if (acceptButton?.classList.contains("is-active")) return true
    if (rejectButton?.classList.contains("is-active")) return false
    return null
  }

  restoreLocalResponses() {
    const responses = this.readLocalResponses()
    Object.entries(responses).forEach(([ taskId, accepted ]) => this.setButtonState(taskId, accepted))
  }

  readLocalResponses() {
    try {
      return JSON.parse(this.readLocal("responses") || "{}")
    } catch (error) {
      return {}
    }
  }

  updateProgress() {
    const stepsCompleted = this.stepTargets.filter((step) => {
      const rows = Array.from(step.querySelectorAll("[data-task-id]"))
      return rows.length > 0 && rows.every((row) => this.currentResponseFor(row.dataset.taskId) !== null)
    }).length

    if (this.hasTotalStepsValue && this.totalStepsValue > 0) {
      const percent = Math.round((stepsCompleted / this.totalStepsValue) * 100)
      if (this.hasProgressFillTarget) this.progressFillTarget.style.width = `${percent}%`
      if (this.hasProgressLabelTarget) {
        this.progressLabelTarget.textContent = `${percent}% complete — ${stepsCompleted} of ${this.totalStepsValue} steps`
      }
    } else {
      if (this.hasProgressFillTarget) this.progressFillTarget.style.width = "0%"
      if (this.hasProgressLabelTarget) {
        this.progressLabelTarget.textContent = `${stepsCompleted} step${stepsCompleted === 1 ? "" : "s"} completed`
      }
    }
  }

  readLocal(key) {
    try {
      return localStorage.getItem(`${this.storageKeyValue}_${key}`)
    } catch (error) {
      return null
    }
  }

  writeLocal(key, value) {
    try {
      localStorage.setItem(`${this.storageKeyValue}_${key}`, value)
    } catch (error) {
      // Private browsing / storage disabled — progress just won't persist.
    }
  }

  clearLocal(key) {
    try {
      localStorage.removeItem(`${this.storageKeyValue}_${key}`)
    } catch (error) {
      // Private browsing / storage disabled — nothing to clear.
    }
  }

  // The stack of step ids visited before the current one, so "Previous" can
  // retrace a conditional branch instead of just decrementing an index —
  // persisted alongside current_step so it survives a reload.
  pushHistory() {
    const currentStepId = this.readLocal("current_step")
    if (!currentStepId) return

    const history = this.readHistory()
    history.push(currentStepId)
    this.writeHistory(history)
  }

  readHistory() {
    try {
      return JSON.parse(this.readLocal("history") || "[]")
    } catch (error) {
      return []
    }
  }

  writeHistory(history) {
    this.writeLocal("history", JSON.stringify(history))
  }
}
