// Hardware Fingerprinting Engine for 1-Device-1-Student Binding

export async function getDeviceIdentity() {
  // 1. Retrieve or generate persistent device ID
  let deviceId = localStorage.getItem('sy_device_id');
  if (!deviceId) {
    deviceId = 'dev_' + Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
    localStorage.setItem('sy_device_id', deviceId);
  }

  // 2. Generate Hardware Profile Hash (Canvas + WebGL + Screen + Hardware)
  const components = [];

  // Screen metrics
  components.push(`screen:${window.screen.width}x${window.screen.height}x${window.screen.colorDepth}`);
  components.push(`dpr:${window.devicePixelRatio || 1}`);
  components.push(`cores:${navigator.hardwareConcurrency || 4}`);

  // Canvas fingerprinting
  try {
    const canvas = document.createElement('canvas');
    canvas.width = 200;
    canvas.height = 50;
    const ctx = canvas.getContext('2d');
    if (ctx) {
      ctx.textBaseline = 'top';
      ctx.font = "14px 'Arial'";
      ctx.textBaseline = 'alphabetic';
      ctx.fillStyle = '#f60';
      ctx.fillRect(125, 1, 62, 20);
      ctx.fillStyle = '#069';
      ctx.fillText('SY_ATTENDANCE_2026', 2, 15);
      ctx.fillStyle = 'rgba(102, 204, 0, 0.7)';
      ctx.fillText('SY_ATTENDANCE_2026', 4, 17);
      components.push(`canvas:${canvas.toDataURL().slice(-50)}`);
    }
  } catch (e) {
    components.push('canvas:error');
  }

  // WebGL fingerprinting
  try {
    const canvas = document.createElement('canvas');
    const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
    if (gl) {
      const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
      if (debugInfo) {
        components.push(`gpu_vendor:${gl.getParameter(debugInfo.UNMASKED_VENDOR_WEBGL)}`);
        components.push(`gpu_renderer:${gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL)}`);
      }
    }
  } catch (e) {
    components.push('webgl:error');
  }

  // Combine into a simple fast hex hash
  const rawString = components.join('|||');
  let hash = 0;
  for (let i = 0; i < rawString.length; i++) {
    const char = rawString.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash |= 0; // Convert to 32bit integer
  }
  const fingerprint = 'fp_' + Math.abs(hash).toString(16).padStart(8, '0');

  return {
    deviceId,
    fingerprint
  };
}
