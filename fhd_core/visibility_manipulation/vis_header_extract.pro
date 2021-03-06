FUNCTION vis_header_extract,header,params=params,lon=lon,lat=lat,alt=alt,error=error
compile_opt idl2,strictarrsubs  

pol_dim=2
freq_dim=4
real_index=0
imaginary_index=1
flag_index=2

n_extensions=sxpar(header,'nextend')
naxis=sxpar(header,'naxis') ;6
n_grp_params=sxpar(header,'pcount') ;5
nbaselines=sxpar(header,'gcount') ;variable, based on length of observation
n_complex=sxpar(header,'naxis2') ;3 columns are amplitude, phase (degrees), weights
n_pol=sxpar(header,'naxis3') ;4 columns are xx, yy, xy, yx
n_freq=sxpar(header,'naxis4') ;768
freq_ref=sxpar(header,'crval4') ;1.5424E8
freq_res=sxpar(header,'cdelt4') ;40000 
IF freq_res EQ 0 THEN print,'WARNING: Invalid frequency resolution in uvfits header! Uses header keyword cdelt4'
freq_ref_i=sxpar(header,'crpix4') -1;368-1 (Remember, FITS indices start from 1, IDL indices start from 0)
date_obs=sxpar(header,'date-obs')
frequency_array=(findgen(n_freq)-(freq_ref_i-1))*freq_res+freq_ref 
n_fields=sxpar(header,'tfields') ;12

n_grp_params=sxpar(header,'pcount')
param_list=Strarr(n_grp_params)
ptype_list=String(format='("PTYPE",I1)',indgen(n_grp_params)+1)
FOR pi=0,n_grp_params-1 DO param_list[pi]=StrTrim(sxpar(header,ptype_list[pi]),2)

param_names = strlowcase(strtrim(sxpar(header, 'CTYPE*'), 2))
wh_ra = where(param_names eq 'ra', count_ra)
if count_ra eq 1 then ra_cnum = wh_ra[0]+1 else message, 'RA CTYPE not found'
wh_dec = where(param_names eq 'dec', count_dec)
if count_dec eq 1 then dec_cnum = wh_dec[0]+1 else message, 'DEC CTYPE not found'

obsra=sxpar(header,'CRVAL' + strn(ra_cnum))
obsdec=sxpar(header,'CRVAL' + strn(dec_cnum))  

IF N_Elements(lon) EQ 0 THEN lon=116.67081524 & lon=Float(lon);degrees (MWA, from Tingay et al. 2013)
IF N_Elements(lat) EQ 0 THEN lat=-26.7033194 & lat=Float(lat);degrees (MWA, from Tingay et al. 2013)
IF N_Elements(alt) EQ 0 THEN alt=377.827 & alt=Float(alt);altitude (meters) (MWA, from Tingay et al. 2013)

baseline_i=(where(Strmatch(param_list,'BASELINE', /fold_case),found_baseline))[0] & IF found_baseline NE 1 THEN print,"WARNING: Group parameter BASELINE not found within uvfits header PTYPE keywords" 
uu_i=(where(Strmatch(param_list,'UU', /fold_case),found_uu))[0] & IF found_uu NE 1 THEN print,"WARNING: Group parameter UU not found within uvfits header PTYPE keywords"
vv_i=(where(Strmatch(param_list,'VV', /fold_case),found_vv))[0] & IF found_vv NE 1 THEN print,"WARNING: Group parameter VV not found within uvfits header PTYPE keywords"
ww_i=(where(Strmatch(param_list,'WW', /fold_case),found_ww))[0] & IF found_ww NE 1 THEN print,"WARNING: Group parameter WW not found within uvfits header PTYPE keywords"
date_i=where(Strmatch(param_list,'DATE', /fold_case),found_date) & IF found_date LT 1 THEN print,"WARNING: Group parameter DATE not found within uvfits header PTYPE keywords"
IF (found_baseline NE 1) OR (found_uu NE 1) OR (found_vv NE 1) OR (found_ww NE 1) OR (found_date LT 1) THEN error=1 
ant1_i = where(Strmatch(param_list,'ANTENNA1', /fold_case),found_ant1)
ant2_i = where(Strmatch(param_list,'ANTENNA2', /fold_case),found_ant2)

IF found_date GT 1 THEN BEGIN
    Jdate0=Double(sxpar(header,String(format='("PZERO",I1)',date_i[0]+1))) + Double(params[date_i[0],0])
    date_i=date_i[1]
ENDIF ELSE BEGIN
    Jdate0=Double(sxpar(header,String(format='("PZERO",I1)',date_i+1)))
ENDELSE
;Jdate_extract=sxpar(header,String(format='("PZERO",I1)',date_i+1),count=found_jd0)
;IF Keyword_Set(found_jd0) THEN IF Jdate_extract GT 2.4E6 THEN Jdate0=Jdate_extract

grp_row_size=n_complex*n_pol*n_freq*nbaselines

hdr=fhd_struct_init_hdr(n_grp_params=n_grp_params,nbaselines=nbaselines,n_tile=n_tile,n_pol=n_pol,n_freq=n_freq,$
    freq_res=freq_res,freq_arr=frequency_array,lon=lon,lat=lat,alt=alt,obsra=obsra,obsdec=obsdec,$
    uu_i=uu_i,vv_i=vv_i,ww_i=ww_i,baseline_i=baseline_i,date_i=date_i,jd0=Jdate0,date_obs=date_obs,$
    pol_dim=pol_dim,freq_dim=freq_dim,real_index=real_index,imaginary_index=imaginary_index,$
    flag_index=flag_index, ant1_i=ant1_i, ant2_i=ant2_i)

RETURN,hdr
END