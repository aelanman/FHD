FUNCTION fhd_init,obs,skymodel,file_path_fhd=file_path_fhd,pol_use=pol_use,freq_use=freq_use,time_i_use=time_i_use,$
    gain_factor=gain_factor,$
    max_iter=max_iter,check_iter=check_iter,max_add_sources=max_add_sources,max_sources=max_sources,$
    smooth_width=smooth_width,beam_threshold=beam_threshold,add_threshold=add_threshold,$
    independent_fit=independent_fit,deconvolution_filter=deconvolution_filter,$
    beam_max_threshold=beam_max_threshold,sigma_cut=sigma_cut,local_max_radius=local_max_radius,$
    reject_pol_sources=reject_pol_sources,filter_background=filter_background,$
    galaxy_model_fit=galaxy_model_fit,transfer_mapfn=transfer_mapfn,$
    subtract_sidelobe_catalog=subtract_sidelobe_catalog,return_sidelobe_catalog=return_sidelobe_catalog,$
    joint_deconvolution_list=joint_deconvolution_list,dft_deconvolution_threshold=dft_deconvolution_threshold,$
    deconvolution_over_resolution=deconvolution_over_resolution,deconvolution_horizon_threshold=deconvolution_horizon_threshold


IF N_Elements(obs) EQ 0 THEN BEGIN
    dimension=1024. 
    n_pol=4
    beam_width=1.
    IF N_Elements(dft_deconvolution_threshold) EQ 0 THEN dft_deconvolution_threshold=1. 
ENDIF ELSE BEGIN
    IF N_Elements(dft_deconvolution_threshold) EQ 0 THEN $
        IF Keyword_Set(obs.dft_threshold) THEN dft_deconvolution_threshold=obs.dft_threshold ELSE dft_deconvolution_threshold=1. 
    dimension=obs.dimension
    n_pol=obs.n_pol
    beam_width=beam_width_calculate(obs,/fwhm)/2.
ENDELSE
IF dft_deconvolution_threshold GE 1 THEN dft_deconvolution_threshold=1./((2.*!Pi)^2.*dimension) $ ;explicitly set to 0 to use analytic DFT. ;1/2 value of kernel_test along either axis at the edge of the image.
    ELSE dft_deconvolution_threshold=Float(dft_deconvolution_threshold)

IF N_Elements(file_path_fhd) EQ 0 THEN file_path_fhd=''
IF N_Elements(pol_use) EQ 0 THEN pol_use=indgen(n_pol)
IF N_Elements(beam_max_threshold) EQ 0 THEN beam_max_threshold=1e-4 
IF N_Elements(smooth_width) EQ 0 THEN smooth_width=32.;Float(Ceil(beam_width*10.)) & smooth_width=smooth_width>5.
IF N_Elements(local_max_radius) EQ 0 THEN local_max_radius=3.
IF N_Elements(sigma_cut) EQ 0 THEN sigma_cut=2.
IF N_Elements(beam_threshold) EQ 0 THEN beam_threshold=0.05 ;0.05 is really as far down as you should go with our current beam models!
IF N_Elements(max_sources) EQ 0 THEN max_sources=100000.
IF N_Elements(gain_factor) EQ 0 THEN gain_factor=.15
IF N_Elements(add_threshold) EQ 0 THEN add_threshold=0.8 ;also fit additional components brighter than this threshold
IF N_Elements(max_add_sources) EQ 0 THEN max_add_sources=0L ;turn off max as default
IF N_Elements(max_iter) EQ 0 THEN IF max_add_sources EQ 1 THEN max_iter=max_sources ELSE max_iter=500.
IF N_Elements(check_iter) EQ 0 THEN IF max_add_sources EQ 1 THEN check_iter=Round(5./gain_factor) ELSE check_iter=Round(1./gain_factor)<5
IF N_Elements(independent_fit) EQ 0 THEN independent_fit=0 ;set to 1 to fit I, Q, (U, V) seperately. Otherwise, only I (and U) is fit
IF N_Elements(reject_pol_sources) EQ 0 THEN reject_pol_sources=0 ;set to exclude source candidates with high Stokes Q/I
IF N_Elements(transfer_mapfn) EQ 0 THEN transfer_mapfn='False'
IF N_Elements(filter_background) EQ 0 THEN filter_background=1
IF N_Elements(galaxy_model_fit) EQ 0 THEN galaxy_model_fit=0
IF N_Elements(joint_deconvolution_list) LE 1 THEN decon_mode='Single snapshot' ELSE decon_mode='HEALPix integrated'
IF N_Elements(joint_deconvolution_list) EQ 0 THEN joint_obs=file_basename(file_path_fhd) ELSE joint_obs=file_basename(joint_deconvolution_list)
IF N_Elements(deconvolution_filter) EQ 0 THEN deconvolution_filter='filter_uv_uniform'
IF N_Elements(deconvolution_over_resolution) EQ 0 THEN over_resolution=2 ELSE over_resolution=deconvolution_over_resolution
IF N_Elements(deconvolution_horizon_threshold) EQ 0 THEN deconvolution_horizon_threshold=10. ;degrees above the horizon to exclude from deconvolution
IF N_Elements(subtract_sidelobe_catalog) EQ 0 THEN sidelobe_subtract='' ELSE BEGIN
    IF size(subtract_sidelobe_catalog,/type) EQ 7 THEN sidelobe_subtract=subtract_sidelobe_catalog ELSE BEGIN
        IF Keyword_Set(subtract_sidelobe_catalog) THEN IF N_Elements(skymodel) GT 0 THEN sidelobe_subtract=skymodel.catalog_name ELSE BEGIN
            IF N_Elements(obs) GT 0 THEN sidelobe_subtract=obs.instrument+'_calibration_source_list' ELSE sidelobe_subtract='' 
        ENDELSE
    ENDELSE
ENDELSE
IF N_Elements(return_sidelobe_catalog) EQ 0 THEN sidelobe_return=0 $
    ELSE sidelobe_return=Keyword_Set(sidelobe_subtract) ? return_sidelobe_catalog:0
end_condition='Not successfully run'
n_iter=0
n_components=0L
n_sources=0L
detection_threshold=0.
convergence=0.
info=Ptr_new()

fhd_params={npol:n_pol,beam_threshold:beam_threshold,max_iter:max_iter,max_sources:max_sources,check_iter:check_iter,$
    gain_factor:gain_factor,add_threshold:add_threshold,max_add_sources:max_add_sources,$
    over_resolution:over_resolution,dft_threshold:dft_deconvolution_threshold,independent_fit:independent_fit,$
    reject_pol_sources:reject_pol_sources,beam_max_threshold:beam_max_threshold,horizon_threshold:deconvolution_horizon_threshold,smooth_width:smooth_width,$
    pol_use:pol_use,sigma_cut:sigma_cut,local_max_radius:local_max_radius,transfer_mapfn:transfer_mapfn,$
    galaxy_subtract:galaxy_model_fit,sidelobe_subtract:sidelobe_subtract,sidelobe_return:sidelobe_return,$
    filter_background:filter_background,decon_filter:deconvolution_filter,decon_mode:decon_mode,$
    joint_obs:joint_obs,end_condition:end_condition,n_iter:n_iter,n_components:n_components,n_sources:n_sources,$
    detection_threshold:detection_threshold,convergence:convergence,info:info}

RETURN,fhd_params
END