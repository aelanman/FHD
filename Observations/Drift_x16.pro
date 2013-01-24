PRO Drift_x16,cleanup=cleanup,ps_export=ps_export
except=!except
!except=0 
heap_gc

IF N_Elements(cleanup) EQ 0 THEN cleanup=0
IF N_Elements(ps_export) EQ 0 THEN ps_export=0
version=0

data_directory=rootdir('mwa')+filepath('',root='DATA',subdir=['X16','Drift'])
vis_file_list=file_search(data_directory,'*_cal.uvfits',count=n_files)
fhd_file_list=fhd_path_setup(vis_file_list,version=version)

healpix_path=fhd_path_setup(output_dir=data_directory,subdir='Healpix',output_filename='Combined_obs')

catalog_file_path=filepath('MRC full radio catalog.fits',root=rootdir('mwa'),subdir='DATA')
;filename_list=filename_list[[0,25]]

;filename_list=Reverse(filename_list)

n_files=N_Elements(vis_file_list)
FOR fi=0,n_files-1 DO BEGIN
    beam_recalculate=0
    healpix_recalculate=0
    mapfn=0
    flag=0
    grid=0
    deconvolve=0
    no_output=0
    noise_calibrate=0
    align=0
    dimension=1024.
    max_sources=10000.
    image_filter_fn='filter_uv_hanning' ;applied ONLY to output images
    uvfits2fhd,vis_file_list[fi],file_path_fhd=fhd_file_list[fi],n_pol=2,$
        independent_fit=0,reject_pol_sources=0,beam_recalculate=beam_recalculate,$
        mapfn_recalculate=mapfn,flag=flag,grid=grid,healpix_recalculate=healpix_recalculate,$
        /silent,max_sources=max_sources,deconvolve=deconvolve,catalog_file_path=catalog_file_path,$
        no_output=no_output,noise_calibrate=noise_calibrate,align=align,$
        dimension=dimension,image_filter_fn=image_filter_fn
ENDFOR

map_projection='orth'
;flux_scale=79.4/2651. ;set 3C444 to catalog value
combine_obs_sources,fhd_file_list,calibration,source_list,restore_last=0,output_path=healpix_path
combine_obs_healpix,fhd_file_list,hpx_inds,residual_hpx,weights_hpx,dirty_hpx,sources_hpx,restored_hpx,smooth_hpx,$
    nside=nside,restore_last=0,flux_scale=flux_scale,output_path=healpix_path,obs_arr=obs_arr
combine_obs_hpx_image,fhd_file_list,hpx_inds,residual_hpx,weights_hpx,dirty_hpx,sources_hpx,restored_hpx,smooth_hpx,$
    weight_threshold=0.5,fraction_pol=0.5,high_dirty=6.0,low_dirty=-1.5,high_residual=3.0,high_source=3.0,$
    nside=nside,output_path=healpix_path,restore_last=0,obs_arr=obs_arr,map_projection=map_projection

calibration_test,fhd_file_list,output_path=healpix_path

IF Keyword_Set(ps_export) THEN BEGIN
    vis_split_export_multi,n_avg=n_avg,output_path=healpix_path,vis_file_list=vis_file_list,fhd_file_list=fhd_file_list
ENDIF
IF Keyword_Set(cleanup) THEN FOR fi=0,n_files-1 DO fhd_cleanup,fhd_file_list[fi]
!except=except
END