# README images

`shoji.png` is the app screenshot at the top of the README; `icon.png` is the app icon, rendered with `ictool`.

## Retaking the screenshot

Never shoot real threads: their names, folders, prompts and the machine's hostname would end up on GitHub. Run a separate Shoji Debug with an invented home instead.

1. **Demo home.** Build Debug, then make a home under `build/`, which git ignores: `build/demo-home`. Keep the path short; the hook socket path must stay under 104 characters, or Shoji runs without hooks. In it, write `Library/Application Support/Shoji-Debug/threads.json` (schema 1, invented threads whose `~/…` folders exist under the demo home, and a `layout.root` split tree; see PLAN › `threads.json`) and `zdot/.zshrc`.
2. **Scenes instead of sessions.** The `.zshrc` prints `$ZDOTDIR/scenes/$SHOJI_THREAD_ID.ans` with `cat`, then runs `sleep 86400`, so no real prompt or agent ever shows. A scene starts with what Shoji reads from a shell: `ESC ]1337;ShojiEvent=cmd;<command> BEL` (the card's tag and agent) and, for an agent, a title `ESC ]0;✳ <topic> BEL` (the card's name). Then comes ANSI text (a Claude Code transcript, server logs), and `ESC [?25l` hides the cursor. Size it to the panes: about 90 columns for a wide pane.
3. **Launch apart from the real Debug app:** `open -n -a build/Build/Products/Debug/Shoji.app --env CFFIXED_USER_HOME=$D --env HOME=$D --env ZDOTDIR=$D/zdot --args -notifyWhenAway '<false/>'`, with `D` the demo home's absolute path. `CFFIXED_USER_HOME` gives it its own support folder, threads and socket. The argument keeps notifications quiet without changing saved settings.
4. **Statuses through hooks.** Pipe hook JSON into `scripts/shoji-hook` with `SHOJI_SOCKET` set to the demo socket and `SHOJI_THREAD_ID` to the thread:
   - `{"hook_event_name":"UserPromptSubmit","session_id":"demo"}` makes it working;
   - `{"hook_event_name":"Notification","notification_type":"permission_prompt","message":"…"}` makes it need you;
   - `{"hook_event_name":"Stop"}` makes it done, and unseen while its pane isn't focused.

   Space them a minute or two apart so the cards show different elapsed times.
5. **Shoot the window** with ⌘⇧4, then Space, then a click on the window. That keeps the shadow, which suits both GitHub themes. Don't click inside first: focusing a pane changes the states.
6. **Clean up.** Quit the demo with `kill <pid>`; `tell application id …` may pick your other Debug app. Then delete `build/demo-home`.
