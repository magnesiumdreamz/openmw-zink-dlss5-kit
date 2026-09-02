# OpenMW Zink stability milestone

Date: 2026-09-01

## Result

An isolated runtime at `runtime/openmw-0.51.0-zink-stability` fixes the observed
desktop transparency, blended-texture transparency, and location-dependent
white/grey flashing. Live resolution changes also survived two controlled
transitions while DLSS resources were rebuilt at the correct dimensions.

The previous known-good runtime at `runtime/openmw-0.51.0-zink` was not modified.

## Transparency and flashing

ReShade logged Zink swapchains with `compositeAlpha = 0x2`, Vulkan's
premultiplied-alpha mode. OpenMW writes useful material/UI alpha to its framebuffer,
so Windows composition exposed the wallpaper and other windows through those pixels.
Alpha-zero or partially initialized frames could also manifest as white/grey flashes.

`shaders/OpenMW_OpaquePresent.fx` is enabled after `DLSS5_Feed`. It preserves the
completed RGB result and writes alpha 1.0 only at final presentation. User testing
confirmed that this fixed the graphical glitches.

An attempted explicit Vulkan layer that changed the swapchain to opaque composition
failed during Vulkan instance creation with `VK_ERROR_OUT_OF_HOST_MEMORY`. It was
removed from the launcher and is not part of the working configuration.

## Live resolution changes

The first in-app resolution change crashed after ReShade warned that a depth-stencil
resource was destroyed while still in use. The feeder drained its private D3D12 queue
but did not wait for the final copy on the game's Vulkan queue before destroying the
imported Vulkan images.

The feeder now resolves `vkDeviceWaitIdle` and waits for the Vulkan device before
releasing imported frame resources. The test sequence succeeded:

- 1920x1080 initialization
- live change to 2560x1440; effect runtime recreated and DLSS feature rebuilt
- live change back to 1920x1080; effect runtime recreated and DLSS feature rebuilt

The shared OpenMW settings finished at bordered window mode 2, 1920x1080.

## Files

- generated `Launch-OpenMW-Zink.cmd`
- `shaders/OpenMW_OpaquePresent.fx`
- `patches/dlss5-feeder-vulkan-resize-idle.patch`
- isolated compiled runtime (not distributed)

## Remaining caveats

- ReShade still reports depth-resource and D3D12 descriptor reference warnings on
  final application shutdown. They no longer occurred at the successful live resize
  boundaries, but shutdown cleanup should be audited separately.
- The final alpha pass is a compatibility workaround. A future Mesa/OpenMW-native
  solution should request an opaque Zink swapchain when framebuffer transparency is
  not wanted.
- Motion-vector probes sometimes report zero or implausibly large vectors. That is a
  separate temporal-quality problem and is not addressed by this milestone.
