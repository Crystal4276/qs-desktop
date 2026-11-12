-- Keep the master volume of playback streams at 100 %.
-- Quickshell, pactl and wpctl only show and set channelVolumes; a master `volume` below 1 is invisible everywhere and
-- WirePlumber restores it on every new stream of the app (2026-11-12: Chromium silent at "88 %", volume = 0.000061).
-- Per-app volumes (channelVolumes) are left alone. The warning names the app, to find out who lowers it.

cutils = require ("common-utils")
log = Log.open_topic ("s-node")

SimpleEventHook {
  name = "node/stream-full-volume",
  interests = {
    EventInterest {
      Constraint { "event.type", "=", "node-params-changed" },
      Constraint { "event.subject.param-id", "=", "Props" },
      Constraint { "media.class", "=", "Stream/Output/Audio" },
    },
  },
  execute = function (event)
    local node = event:get_subject ()
    for p in node:iterate_params ("Props") do
      local props = cutils.parseParam (p, "Props")
      if props and props.volume ~= nil and props.volume < 0.9999 then
        log:warning (node, "master volume " .. props.volume .. " of "
            .. tostring (node.properties ["application.name"]) .. " reset to 1.0")
        node:set_param ("Props", Pod.Object { "Spa:Pod:Object:Param:Props", "Props", volume = 1.0 })
      end
    end
  end
}:register ()
