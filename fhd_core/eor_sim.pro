

function eor_sim, u_arr, v_arr, freq_arr, seed = seed, flat_sigma = flat_sigma

  if n_elements(seed) eq 0 then seed = systime(1)
  
  delta_u = u_arr[1] - u_arr[0]
  delta_v = v_arr[1] - v_arr[0]
  f_delta = freq_diff[0]
  n_kz = n_freq
  
  z0_freq = 1420.40 ;; MHz
  redshifts = z0_freq/freq_arr - 1
  cosmology_measures, redshifts, comoving_dist_los = comov_dist_los
  
  comov_los_diff = comov_dist_los - shift(comov_dist_los, -1)
  comov_los_diff = comov_los_diff[0:n_elements(comov_dist_los)-2]
  z_mpc_delta = mean(comov_los_diff)
  z_mpc_mean = mean(comov_dist_los)
  
  ;; convert from uv (in wavelengths) to kx/ky in inverse comoving Mpc
  kx_mpc = u_arr * (2d*!pi) / z_mpc_mean
  kx_mpc_delta = delta_u * (2d*!pi) / z_mpc_mean
  n_kx = n_elements(kx_mpc)
  
  ky_mpc = v_arr * (2d*!pi) / z_mpc_mean
  ky_mpc_delta = delta_v * (2d*!pi) / z_mpc_mean
  n_ky = n_elements(ky_mpc)
  
  ;  kperp_lambda_conv = z_mpc_mean / (2.*!pi)
  ;  delay_delta = 1e9/(n_freq*f_delta*1e6) ;; equivilent delay bin size for kparallel
  ;  delay_max = delay_delta * n_freq/2.    ;; factor of 2 b/c of neg/positive
  ;  delay_params = [delay_delta, delay_max]
  
  z_mpc_length = max(comov_dist_los) - min(comov_dist_los) + z_mpc_delta
  kz_mpc_range =  (2.*!pi) / (z_mpc_delta)
  kz_mpc_delta = (2.*!pi) / z_mpc_length
  kz_mpc_orig = findgen(round(kz_mpc_range / kz_mpc_delta)) * kz_mpc_delta - kz_mpc_range/2.
  if n_elements(kz_mpc_orig) ne n_kz then stop
  
  ;; savefile contains: k_centers, power
  ;restore, base_path('data') + 'eor_data/eor_power_1d.idlsave' ;;k_centers, power
  restore, filepath('eor_power_1d.idlsave',root=rootdir('FHD'),subdir='catalog_data')
  
  npts_log = n_elements(k_centers)
  
  log_diff =  alog10(k_centers) - shift(alog10(k_centers), 1)
  log_diff = log_diff[1:*]
  log_binsize = log_diff[0]
  
  if n_elements(flat_sigma) ne 0 then begin
    power_3d = dblarr(n_kx, n_ky, n_kz) + flat_sigma
    
  endif else begin
  
    k_arr = sqrt(rebin(kx_mpc, n_kx, n_ky, n_kz)^2d + rebin(reform(ky_mpc, 1, n_ky), n_kx, n_ky, n_kz)^2d + $
      rebin(reform(kz_mpc, 1, 1, n_kz), n_kx, n_ky, n_kz)^2d)
    wh0 = where(k_arr eq 0, count)
    if count ne 0 then k_arr[wh0] = min(k_centers)
    
    result = 10^(interpol(alog10(power), alog10(k_centers), alog10(k_arr)))
    
    power_3d = reform(temporary(result), n_kx, n_ky, n_kz)
    
    mu = rebin(reform(abs(kz_mpc), 1, 1, n_kz), n_kx, n_ky, n_kz) / temporary(k_arr)
    power_3d = power_3d * (1 + 2 * mu^2d + mu^4d)
    
    mu=0
  endelse
  
  signal_amp = sqrt(power_3d)
  signal_phase = randomu(seed, n_kx, n_ky, n_kz) * 2d * !pi
  
  signal = temporary(signal_amp) * exp(dcomplex(0,1) * temporary(signal_phase))
  
  ;; shift it so that it's as expected when we take the fft
  signal = shift(temporary(signal), [0,0,n_kz/2+1])
  
  print, 'signal^2d integral:', total(abs(signal)^2d)
  print, 'signal^2d integral * 2pi*delta_k^2d:', total(abs(signal)^2d) * kz_mpc_delta * 2d * !dpi
  
  ;;temp = conj(reverse(signal[*,*,1:n_kz-2],3))
  ;;signal = [[[signal]], [[temp]]]
  
  ;; fourier transform along z direction to get to uvf space
  temp = fft(temporary(signal), dimension = 3, /inverse) * kz_mpc_delta
  
  print, 'sum(uvf signal^2)*z_delta:', total(abs(temp)^2d)*z_mpc_delta
  
  signal = temp
  return, signal
end