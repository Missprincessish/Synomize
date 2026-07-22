# Angie Quest Smoke Test

1. In the Meta Horizon phone app, enable Developer Mode for this headset if it is not already enabled.
2. Turn on the Quest, confirm its floor boundary, and connect it to the Mac with a USB data cable.
3. Put on the headset and approve USB debugging. Choose **Always allow from this computer**.
4. On the Mac, run this single command:

   `/Users/angie/Documents/SYN_HUMANITY_MASTER/VectorVerse-Godot/scripts/install_and_launch_quest_smoke.sh`

5. Put the headset back on. The app is named **Synomize Quest Smoke Test**. If it did not open automatically, find it in the Quest library under **Unknown Sources** and open it.

## What to test

1. Look left, right, up, and down. The world should follow your head without becoming a flat window.
2. Raise both controllers. The debug text should show `HEADSET: TRACKED`, `LEFT: TRACKED`, and `RIGHT: TRACKED`.
3. Move each controller separately. Its green or cyan ray should follow it.
4. **Don't see the floating black panel?** The Quest's Guardian orientation doesn't always match which way you're facing when the app starts. Hold both triggers down at the same time (while not grabbing anything) to snap the panel to face wherever you're currently looking. You can repeat this as many times as you need.
5. Point at **APP START**. Hold either index trigger or side grip, aim at the glowing Event socket, then release. It should insert and reveal only **LOG / DISPLAY**.
6. Point at **LOG / DISPLAY**. Hold trigger or side grip, aim at the Action socket, then release. It should insert and reveal Generate.
7. Point at **CREATE** and press trigger. The panel should show `✔ Program Complete`, then `Generating...`, followed by the generated code and language selector.
8. Report exactly where anything failed, which hand/button was used, and what the debug tracking text showed.

This is a smoke test. VR interaction is not accepted until these steps succeed on the real headset.

## Confirmed passing (2026-07-17)

Angie completed the full sequence on the real Quest 3S: panel visible, App Start and Log/Display grabbed and snapped into both sockets, Generate produced `GDSCRIPT PARSED // RUNTIME VERIFIED` and `Hello, Synomize!`. See `evidence/quest_headset_acceptance_evidence.json`.
