function [H1,handles,home_dir] = mirone_uis(home_dir)
% Creates and returns a handle to the GUI MIRONE figure.

%	Copyright (c) 2004-2020 by J. Luis
%
% 	This program is part of Mirone and is free software; you can redistribute
% 	it and/or modify it under the terms of the GNU Lesser General Public
% 	License as published by the Free Software Foundation; either
% 	version 2.1 of the License, or any later version.
% 
% 	This program is distributed in the hope that it will be useful,
% 	but WITHOUT ANY WARRANTY; without even the implied warranty of
% 	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
% 	Lesser General Public License for more details.
%
%	Contact info: w3.ualg.pt/~jluis/mirone
% --------------------------------------------------------------------

% $Id: mirone_uis.m 11388 2018-10-11 13:31:24Z j $

%#function pan igrf_options rally_plater plate_calculator ecran snapshot
%#function about_box parker_stuff euler_stuff grid_calculator tableGUI usgs_recent_seismicity
%#function datasets_funs earthquakes manual_pole_adjust compute_euler focal_meca srtm_tool atlas
%#function image_enhance image_adjust write_gmt_script vitrinite telhometro mpaint
%#function imcapture filter_funs overview imageresize classificationfig tfw_funs mirone_pref
%#function griding_mir grdfilter_mir grdsample_mir grdtrend_mir grdgradient_mir ml_clip show_palette 
%#function geog_calculator color_palettes diluvio fault_models tsu_funs mk_movie_from_list
%#function mxgridtrimesh aquamoto tiles_tool empilhador grdlandmask_win escadeirar
%#function run_cmd line_operations world_is_not_round_enough cartas_militares ice_m magbarcode
%#function obj_template_detect floodfill meca_studio inpaint_nans globalcmt guess_bin demets_od
%#function vector_project tintol makescale mesher_helper update_gmt surface_options plot_composer
%#function isoc_selector argo_floats tmd_osu test_bots euler_poles_selector

	% The following test will tell us if we are using the compiled or the ML version
	try
		s = which('mirone');	clear s
		figW = 711;
		IamCompiled = false;
	catch
		figW = 790;				% Compiled version needs to be longer (TMW doesn't know compatibility)
		IamCompiled = true;
	end

	IAmAMac = strncmp(computer,'MAC',3);
	if (IAmAMac),	figW = 900;		end		% On Macs buttons have different sizes

	IAmOctave = (exist('OCTAVE_VERSION','builtin') ~= 0);	% To know if we are running under Octave
	if (IAmOctave),	figW = 800;		end		% QtHandles has different padding size

	% Attempt to deal with the new stupid high-resolution screens that turn Mirone main fig into a dwarf.
	dpis = get(0,'ScreenPixelsPerInch');	% screen DPI
	figW_cm = figW / dpis * 2.54;
	if (figW_cm < 17)						% Both the 17 and 20 (cm) are guessings
		figW = 20 * dpis / 2.54;
	end

	% Import icons and fetch home_dir if compiled and called by extension association
	% Here is what will happen. When called by windows extension association the 'home_dir'
	% will contain the path of the file and not of the Mirone installation, and it will fail.
	% In the 'catch' branch we check if the MIRONE_HOME environment variable exists. If yes
	% its value, the correct home_dir, is returned back to mirone.m
% 	icos = {'ladrilhos', 'olho_ico', 'Mfnew_ico', 'Mfopen_ico', 'Mfsave_ico', 'tools_ico', 'text_ico', ...
% 		'circ_ico', 'Mline_ico', 'rectang_ico', 'polygon_ico', 'Marrow_ico', 'zoom_ico', 'mao', 'cut_ico', ...
% 		'color_ico', 'shade2_ico', 'anaglyph_ico', 'MB_ico', 'olho_ico', 'GE_ico', 'refresh_ico', 'info_ico'};
	try
		load([home_dir filesep 'data' filesep 'mirone_icons.mat']);
	catch
		if (IamCompiled && ispc)
			home_dir = winqueryreg('HKEY_CURRENT_USER', 'Environment', 'MIRONE3_HOME');
			load([home_dir filesep 'data' filesep 'mirone_icons.mat']);
		end
	end

	if (IAmOctave)
		ladrilhos  = single(ladrilhos / 255);
		shade2_ico = single(shade2_ico / 255);
		MB_ico     = single(MB_ico / 255);
		olho_ico   = single(olho_ico / 255);
	end

	pos = [520 758 figW 21];     % R13 honest figure dimension
	H1 = figure('PaperUnits','centimeters',...
		'CloseRequestFcn',@figure1_CloseRequestFcn,...
		'ResizeFcn',@figure1_ResizeFcn,...
		'KeyPressFcn',@figure1_KeyPressFcn,...
		'Color',get(0,'factoryUicontrolBackgroundColor'),...
		'DoubleBuffer','on',...
		'IntegerHandle','off',...
		'MenuBar','none',...
		'Toolbar', 'none',...
		'Name','Mirone 3.0',...
		'NumberTitle','off',...
		'PaperPositionMode','auto',...
		'PaperSize',[20.984 29.677],...
		'PaperType',get(0,'defaultfigurePaperType'),...
		'Position',pos,...
		'HandleVisibility','callback',...
		'Tag','figure1',...
		'Vis','off');

	setappdata(H1,'IAmAMirone',true)		% Use this appdata to identify Mirone figures
	setappdata(H1,'PixelMode',0)			% Default

	% Detect which matlab version is beeing used. For the moment I'm only interested to know if R13 or >= R14
	version7 = version;
	if (double(version7(1)) > 54),		version7 = sscanf(version7(1:3),'%f');
	else,								version7 = 0;
	end

	if (version7)
		PV = {'DockControls','off'};
		set(H1,PV{:});		% Do it this way to cheat the compiler
	end

hVG = zeros(1,18);		kv = 5;		% hVG will contain the handles of "not valid grid" uis to hide when they are not usable
hTB = uitoolbar('parent',H1, 'BusyAction','queue','HandleVisibility','on','Interruptible','on',...
	'Tag','FigureToolBar','Vis','on');
uipushtool('parent',hTB,'Click','mirone(''TransferB_CB'',guidata(gcbo),''NewEmpty'')', ...
	'Tag','NewFigure','cdata',Mfnew_ico,'Tooltip','Open New figure');
uipushtool('parent',hTB,'Click','mirone(''TransferB_CB'',guidata(gcbo),''guessType'')', ...
	'Tag','ImportKnownTypes','cdata',Mfopen_ico,'Tooltip','Load recognized file types');
uipushtool('parent',hTB,'Click','mirone(''TransferB_CB'',guidata(gcbo),''BgMap'')', ...
	'Tag','LoadBGMap','cdata',ladrilhos,'Tooltip','Base Map');
hVG(1) = uipushtool('parent',hTB,'Click','mirone(''FileSaveGMTgrid_CB'',guidata(gcbo))', ...
	'Tag','SaveGMTgrid','cdata',Mfsave_ico,'Tooltip','Save netCDF grid');
uipushtool('parent',hTB,'Click','mirone_pref(guidata(gcbo))', ...
	'Tag','Preferences','cdata',tools_ico,'Tooltip','Preferences');
uipushtool('parent',hTB,'Click','mirone(''Draw_CB'',guidata(gcbo),''Text'')', ...
	'Tag','DrawText','cdata',text_ico,'Tooltip','Insert Text','Sep','on');
uipushtool('parent',hTB,'Click','mirone(''DrawGeogCircle_CB'',guidata(gcbo))', ...
	'Tag','DrawGeogCirc','cdata',circ_ico,'Tooltip','Draw geographical circle');
uipushtool('parent',hTB,'Click','mirone(''DrawLine_CB'',guidata(gcbo))', ...
	'Tag','DrawLine','cdata',Mline_ico,'Tooltip','Draw Line');
uipushtool('parent',hTB,'Click','mirone(''DrawClosedPolygon_CB'',guidata(gcbo),''rectangle'')', ...
	'Tag','DrawRect','cdata',rectang_ico,'Tooltip','Draw Rectangle');
uipushtool('parent',hTB,'Click','mirone(''DrawClosedPolygon_CB'',guidata(gcbo),[])', ...
	'Tag','DrawPolyg','cdata',polygon_ico,'Tooltip','Draw Closed Polygon');
uipushtool('parent',hTB,'Click','mirone(''Draw_CB'',guidata(gcbo),''Vector'')', ...
	'Tag','DrawArrow','cdata',Marrow_ico,'Tooltip','Draw Arrow');
uitoggletool('parent',hTB,'Click','mirone(''PanZoom_CB'',guidata(gcbo),gcbo,''zoom'')', ...
	'Tag','Zoom','cdata',zoom_ico,'Tooltip','Zooming on/off','Sep','on');
uitoggletool('parent',hTB,'Click','mirone(''PanZoom_CB'',guidata(gcbo),gcbo,''pan'')', ...
	'Tag','Mao','cdata',mao,'Tooltip','Pan');
uitoggletool('parent',hTB,'Click','draw_funs(gcbo,''deleteObj'')', ...
	'Tag','Tesoura','cdata',cut_ico,'Tooltip','Delete objects');
uipushtool('parent',hTB,'Click','color_palettes(guidata(gcbo))', ...
	'Tag','ColorPal','cdata',color_ico,'Tooltip','Color Palettes');
hVG(2) = uipushtool('parent',hTB,'Click','mirone(''ImageIllumModel_CB'',guidata(gcbo),''grdgradient_A'')', ...
	'Tag','Shading','cdata',shade2_ico,'Tooltip','Shaded illumination','Sep','on');
hVG(3) = uipushtool('parent',hTB,'Click','mirone(''ImageAnaglyph_CB'',guidata(gcbo))', ...
	'Tag','Anaglyph','cdata',anaglyph_ico,'Tooltip','Anaglyph');
hVG(4) = uipushtool('parent',hTB,'Click','mirone(''ToolsMBplaningStart_CB'',guidata(gcbo))', ...
	'Tag','MBplaning','cdata',MB_ico,'Tooltip','Multi-beam planing');
uipushtool('parent',hTB,'Click','mirone(''FileSaveFleder_CB'',guidata(gcbo),''runPlanar'')', ...  
	'Tag','FlederPlanar','cdata',olho_ico,'Tooltip','Run Fleder 3D Viewer');
uipushtool('parent',hTB,'Click','writekml(guidata(gcbo))', 'Tag','toGE','cdata',GE_ico,'Tooltip','See in Google Earth');
uipushtool('parent',hTB,'Click','bands_list(gcf)','Tag','ImgLayers','cdata',layers_ico,'Tooltip','Load bands','Sep','on');
ico = uint8(ones(16,16,3)*255);
ico(1,:,:) = 50; ico(16,:,:) = 50; ico(:,1,:) = 50; ico(:,16,:) = 50;
ico(6,2:end-1,:) = 100; ico(11,2:end-1,:) = 100; ico(2:15,6,:) = 100; ico(2:15,11,:) = 100;
uipushtool('parent',hTB,'Click','plot_composer(guidata(gcbo))', 'Tag','PlotComposer','cdata',ico,'Tooltip','Plot composer');
uipushtool('parent',hTB,'Click',@refresca, 'Tag','Refresh','cdata',refresh_ico,'Tooltip','Refresh','Sep','on');
uipushtool('parent',hTB,'Click','grid_info(guidata(gcbo))','Tag','ImageInfo','cdata',info_ico,'Tooltip','Image info');

h_axes = axes('Parent',H1,'Units','pixels','Position',[60 0 50 10],'Tag','axes1','Vis','off');
cmenu_axes = uicontextmenu('Parent',H1);
set(h_axes, 'UIContextMenu', cmenu_axes);
uimenu(cmenu_axes, 'Label', 'Label Format -> DD.xx', 'Callback', 'draw_funs([],''ChngAxLabels'',''ToDegDec'')','Tag','LabFormat');
uimenu(cmenu_axes, 'Label', 'Label Format -> DD MM', 'Callback', 'draw_funs([],''ChngAxLabels'',''ToDegMin'')','Tag','LabFormat');
uimenu(cmenu_axes, 'Label', 'Label Format -> DD MM.xx', 'Callback', 'draw_funs([],''ChngAxLabels'',''ToDegMinDec'')','Tag','LabFormat');
uimenu(cmenu_axes, 'Label', 'Label Format -> DD MM SS', 'Callback', 'draw_funs([],''ChngAxLabels'',''ToDegMinSec'')','Tag','LabFormat');
uimenu(cmenu_axes, 'Label', 'Label Format -> DD MM SS.x', 'Callback', 'draw_funs([],''ChngAxLabels'',''ToDegMinSecDec'')','Tag','LabFormat');
itemFS = uimenu(cmenu_axes, 'Label', 'Label Font Size', 'Sep','on');
uimenu(itemFS, 'Label', '8   pt', 'Callback', 'set(gca, ''FontSize'', 8)');
uimenu(itemFS, 'Label', '9   pt', 'Callback', 'set(gca, ''FontSize'', 9)');
uimenu(itemFS, 'Label', '10 pt', 'Callback', 'set(gca, ''FontSize'', 10)');
uimenu(itemFS, 'Label', 'other...', 'Callback', 'draw_funs([],''set_font_size'', gca)');
uimenu(cmenu_axes, 'Label', 'Grid on/off', 'Callback', 'grid', 'Sep','on');
uimenu(cmenu_axes, 'Label', 'Row-Col mode on/off', 'Tag','RCMode', 'Sep','on');
uimenu(cmenu_axes, 'Label', 'Pixel mode on/off', 'Tag','PixMode');
% --- Those ones are manipulated in setAxesDefCoordIn()
uimenu(cmenu_axes, 'Label', 'Load in projected coords', 'Checked','on', 'Vis','off','Tag','hAxMenuLF');
uimenu(cmenu_axes, 'Label', 'Display projected coords', 'Vis','off','Tag','hAxMenuDM');
uimenu(cmenu_axes, 'Label', 'Show Fancy Frame', 'Tag','FancyMode', 'Sep','on');

%% ------------------------ File ----------------------------------------
hFL = uimenu('Parent',H1,'Label','File','Tag','File');
uimenu('Parent',hFL,'Callback','mirone_pref(guidata(gcbo))','Label','Preferences');
uimenu('Parent',hFL,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''NewEmpty'')','Label','New empty window','Sep','on');

h = uimenu('Parent',hFL,'Label','Background window');
uimenu('Parent',h,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''BgMap'')','Label','Map');
uimenu('Parent',h,'Callback','mirone(''FileNewBgFrame_CB'', guidata(gcbo))','Label','Frame');

h2 = uimenu('Parent',hFL,'Label','Open Grid/Image','Sep','on','Tag','OpenGI');
uimenu('Parent',h2,'Callback','mirone(''FileOpenNewImage_CB'',guidata(gcbo));','Label','Images -> Generic Formats');
uimenu('Parent',h2,'Callback','mirone(''FileOpenWebImage_CB'',guidata(gcbo));','Label','Images -> via Web');
uimenu('Parent',h2,'Callback','mirone(''FileOpenDEM_CB'',guidata(gcbo),''GMT'');','Label','GMT Grid','Sep','on');
uimenu('Parent',h2,'Callback','mirone(''FileOpenDEM_CB'',guidata(gcbo),''Surfer'');','Label','Surfer 6/7 grid');
uimenu('Parent',h2,'Callback','mirone(''FileOpenDEM_CB'',guidata(gcbo),''ENCOM'');','Label','Encom grid');
uimenu('Parent',h2,'Callback','mirone(''FileOpenDEM_CB'',guidata(gcbo),''GSOFT'');','Label','Geosoft (2-byte)');
uimenu('Parent',h2,'Callback','mirone(''FileOpenDEM_CB'',guidata(gcbo),''MANI'');','Label','Mani grid');
uimenu('Parent',h2,'Callback','mirone(''FileOpenDEM_CB'',guidata(gcbo),''SSimg'');','Label','Sandwell/Smith Mercator img file');
uimenu('Parent',h2,'Callback','mirone(''FileOpenDEM_CB'',guidata(gcbo),''ArcAscii'');','Label','Arc/Info ASCII Grid','Sep','on');
uimenu('Parent',h2,'Callback','mirone(''FileOpenDEM_CB'',guidata(gcbo),''ArcBinary'');','Label','Arc/Info Binary Grid');
uimenu('Parent',h2,'Callback','mirone(''FileOpenGeoTIFF_CB'',guidata(gcbo),''bsb'');','Label','BSB Nautical Chart Format');
uimenu('Parent',h2,'Callback','mirone(''FileOpen_ENVI_Erdas_CB'',guidata(gcbo),''ENVI'');','Label','ENVI Raster');
uimenu('Parent',h2,'Callback','mirone(''FileOpen_ENVI_Erdas_CB'',guidata(gcbo),''ERDAS'');','Label','Erdas (.img)');
uimenu('Parent',h2,'Callback','mirone(''FileOpenGeoTIFF_CB'',guidata(gcbo),''bil'');','Label','ESRI BIL');
uimenu('Parent',h2,'Callback','mirone(''FileOpenDEM_CB'',guidata(gcbo),''GXF'');','Label','Geosoft GXF');
uimenu('Parent',h2,'Callback','mirone(''FileOpenGeoTIFF_CB'',guidata(gcbo),''geotiff'');','Label','GeoTIFF');
uimenu('Parent',h2,'Callback','mirone(''FileOpenGeoTIFF_CB'',guidata(gcbo),''ecw'');','Label','ECW');
uimenu('Parent',h2,'Callback','mirone(''FileOpenGeoTIFF_CB'',guidata(gcbo),''sid'');','Label','MrSID');
uimenu('Parent',h2,'Callback','mirone(''FileOpenGeoTIFF_CB'',guidata(gcbo),''jp2'');','Label','JPEG2000');
uimenu('Parent',h2,'Callback','mirone(''FileOpenGDALmultiBand_CB'',guidata(gcbo),''ENVISAT'');','Label','ENVISAT','Sep','on');
uimenu('Parent',h2,'Callback','mirone(''FileOpenGDALmultiBand_CB'',guidata(gcbo),''AVHRR'');','Label','AVHRR');
uimenu('Parent',h2,'Callback','mirone(''FileOpenGeoTIFF_CB'',guidata(gcbo),''UNKNOWN'');','Label','Try Luck with GDAL');

% uimenu('Parent',hFL,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''url'')','Label','Get Image from URL');
uimenu('Parent',hFL,'Callback','overview(guidata(gcbo))','Label','Open Overview Tool');
uimenu('Parent',hFL,'Callback','mirone(''FileOpenSession_CB'',guidata(gcbo));','Label','Open Session');

h = uimenu('Parent',hFL,'Label','Open xy(z)','Sep','on');
uimenu('Parent',h,'Callback','load_xyz(guidata(gcbo), [], ''AsLine'')','Label','Import line');
uimenu('Parent',h,'Callback','load_xyz(guidata(gcbo), [], ''AsPoint'')','Label','Import points');
uimenu('Parent',h,'Callback','load_xyz(guidata(gcbo), [], ''AsArrow'')','Label','Import Arrow field');
uimenu('Parent',h,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''scatter'')','Label','Import scaled symbols');
uimenu('Parent',h,'Callback','mirone(''DrawImportText_CB'',guidata(gcbo))','Label','Import text');
uimenu('Parent',h,'Callback','mirone(''DrawImportShape_CB'',guidata(gcbo))','Label','Import shape file');
uimenu('Parent',h,'Callback','read_las(guidata(gcbo))','Label','Import LAS file');
uimenu('Parent',h,'Callback','mirone(''DrawImportOGR_CB'',guidata(gcbo))','Label','Import with OGR', 'Sep','on');

% ----------------------- Save Images section
h = uimenu('Parent',hFL,'Label','Save Image As...','Sep','on');

uimenu('Parent',h,'Callback','snapshot(gcf)', 'Label','Generic Formats');
uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''GeoTiff'',''img'')', 'Label','GeoTiff','Sep','on');
uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''Erdas'',''img'')', 'Label','Erdas Imagine');
uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''Envi'',''img'')', 'Label','Envi .hdr Labeled');
uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''ESRI'',''img'')', 'Label','ESRI .hdr Labeled');
uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''JP2K'',''img'')', 'Label','JPEG2000');
%uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''PDF'',''img'')', 'Label','GeoPDF');
uimenu('Parent',h,'Callback','tfw_funs(''write'',guidata(gcbo))', 'Label','Save .tfw file','Tag','saveTFW','Sep','on');
uimenu('Parent',hFL,'Callback','snapshot(gcf,''frame'')', 'Label','Export ...','Tag','noAxes');

if (strncmp(computer,'PC',2))
    h = uimenu('Parent',hFL,'Label','Copy to Clipboard','Tag','CopyClip');
    uimenu('Parent',h,'Callback','imcapture(gca,''img'');','Label','Image only')
    uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''copyclip'')', 'Label','Image and frame','Tag','noAxes')
	uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''Ctrl-c'')','Label','Copy active line', 'Accel','c', 'Sep','on')
	uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''Ctrl-v'')','Label','Paste line', 'Accel','v')
	%uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''Ctrl-p'')','Label','off', 'Accel','p')
end

uimenu('Parent',hFL,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''KML'')', 'Label','Export to GoogleEarth','Sep','on');

% ----------------------- Save Grids section --------------------- IT ALSO STARTS the hVG(kv)
h = uimenu('Parent',hFL,'Label','Save Grid As...','Sep','on');		hVG(kv) = h;	kv = kv + 1;
uimenu('Parent',h,'Callback','mirone(''FileSaveGMTgrid_CB'',guidata(gcbo))','Label','GMT grid');
uimenu('Parent',h,'Callback','mirone(''FileSaveGMTgrid_CB'',guidata(gcbo),''Surfer'')','Label','Surfer 6 grid');
uimenu('Parent',h,'Callback','mirone(''FileSaveENCOMgrid_CB'',guidata(gcbo))','Label','Encom grid');
uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''GeoTiff'',''grid'')', 'Label','GeoTiff','Sep','on');
uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''Erdas'',''grid'')', 'Label','Erdas Imagine');
uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''Envi'',''grid'')', 'Label','Envi .hdr Labelled');
uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''ESRI'',''grid'')', 'Label','ESRI .hdr Labelled');
uimenu('Parent',h,'Callback','mirone(''FileSaveImgGrdGdal_CB'',guidata(gcbo),''JP2K'',''grid'')', 'Label','JPEG2000');

h = uimenu('Parent',hFL,'Label','Save As 3 GMT grids (R,G,B)');
uimenu('Parent',h,'Callback','mirone(''File_img2GMT_RGBgrids_CB'',guidata(gcbo))','Label','Image only');
uimenu('Parent',h,'Callback','mirone(''File_img2GMT_RGBgrids_CB'',guidata(gcbo),''screen'')','Label','Screen capture');

h = uimenu('Parent',hFL,'Label','Save GMT script','Sep','on');
uimenu('Parent',h,'Callback','write_gmt_script(guidata(gcbo),''bat'')','Label','dos batch');
uimenu('Parent',h,'Callback','write_gmt_script(guidata(gcbo),''csh'')','Label','bash script');

h = uimenu('Parent',hFL,'Label','Save As Fledermaus Objects');
hVG(kv) = uimenu('Parent',h,'Callback','mirone(''FileSaveFleder_CB'',guidata(gcbo),''writeSpherical'')',...
'Label','Spherical Fledermaus Obj');		kv = kv + 1;
uimenu('Parent',h,'Callback','mirone(''FileSaveFleder_CB'',guidata(gcbo),''writePlanar'')','Label','Planar Fledermaus Obj');
hVG(kv) = uimenu('Parent',h,'Callback','mirone(''FileSaveFleder_CB'',guidata(gcbo),''writeAll3'')', ...
'Label','Dmagic .dtm, .geo, .shade files', 'Sep','on');		kv = kv + 1;

uimenu('Parent',hFL,'Callback','mirone(''FileSaveSession_CB'',guidata(gcbo))','Label','Save Session');

if (~IamCompiled)
	h = uimenu('Parent',hFL,'Label','Workspace','Sep','on');
    uimenu('Parent',h,'Label','Grid/Image -> Workspace','Callback','InOut2WS(guidata(gcbo),''direct'')');
    hVG(kv) = uimenu('Parent',h,'Label','Workspace -> Grid','Callback','InOut2WS(guidata(gcbo),''GRID_inverse'')');	kv = kv + 1;
    uimenu('Parent',h,'Label','Workspace -> Image','Callback','InOut2WS(guidata(gcbo),''IMG_inverse'')');
    uimenu('Parent',h,'Label','Clear Workspace','Callback','InOut2WS(guidata(gcbo),''clear'')');
end

h = uimenu('Parent',hFL,'Label','Recent Files','Tag','RecentFiles','Sep','on');
for (i=1:14),    uimenu('Parent',h,'Vis','off','Tag','RecentF');   end

uimenu('Parent',hFL,'Callback','plot_composer(guidata(gcbo))','Label','Plot Composer','Sep','on');
uimenu('Parent',hFL,'Callback','print -dsetup','Label','Print Setup');
uimenu('Parent',hFL,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''print'')','Label','Print...');

%% --------------------------- IMAGE ------------------------------------
hIM = uimenu('Parent',H1,'Label','Image','Tag','Image');

h = uimenu('Parent',hIM,'Label','Color Palettes');
uimenu('Parent',h,'Callback','color_palettes(guidata(gcbo))','Label','Change Palette');
uimenu('Parent',h,'Callback','show_palette(guidata(gcbo),''At'')','Label','Show At side','Tag','PalAt','Sep','on');
uimenu('Parent',h,'Callback','show_palette(guidata(gcbo),''In'')','Label','Show Inside','Tag','PalIn');
uimenu('Parent',h,'Callback','show_palette(guidata(gcbo),''Float'')','Label','Show Floating');
uimenu('Parent',hIM,'Callback','mirone(''ImageCrop_CB'',guidata(gcbo),[])','Label','Crop (interactive)','Sep','on');

h = uimenu('Parent',hIM,'Label','Flip');
uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''flipUD'')','Label','Flip Up-Down');
uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''flipLR'')','Label','Flip Left-Right');

uimenu('Parent',hIM,'Callback','mirone(''ImageResetOrigImg_CB'',guidata(gcbo))','Label','Restore Original Image','Tag','ImRestore');
uimenu('Parent',hIM,'Callback','mirone(''ImageHistEqualize_CB'',guidata(gcbo),gcbo)','Label','Histogram Equalization','Tag','ImgHist');
uimenu('Parent',hIM,'Callback','image_histo(guidata(gcbo))','Label','Show Histogram');

h = uimenu('Parent',hIM,'Label','Illuminate','Tag','Illuminate');	hVG(kv) = h;	kv = kv + 1;
uimenu('Parent',h,'Callback','mirone(''ImageIllumModel_CB'',guidata(gcbo),''grdgradient_A'')','Label','GMT grdgradient');
uimenu('Parent',h,'Callback','mirone(''ImageIllumModel_CB'',guidata(gcbo),''falseColor'')','Label','False color');
uimenu('Parent',h,'Callback','mirone(''ImageAnaglyph_CB'',guidata(gcbo))','Label','Anaglyph');

uimenu('Parent',hIM,'Callback','mirone(''ImageLink_CB'',guidata(gcbo))','Label','Link Displays...','Sep','on');
uimenu('Parent',hIM,'Callback','mirone(''ImageDrape_CB'',guidata(gcbo))','Label','Drape','Tag','ImageDrape','Vis','off');
uimenu('Parent',hIM,'Callback','mirone(''ImageRetroShade_CB'',guidata(gcbo))','Label','Retro-Illuminate','Tag','RetroShade','Vis','off');
h = uimenu('Parent',hIM,'Label','Limits (Map or Image)');
uimenu('Parent',h,'Callback','mirone(''ImageMapLimits_CB'',guidata(gcbo), ''img'')','Label','Image (data) Limits');
uimenu('Parent',h,'Callback','mirone(''ImageMapLimits_CB'',guidata(gcbo), ''map'')','Label','Map (display) Limits');
uimenu('Parent',h,'Callback','mirone(''ImageMapLimits_CB'',guidata(gcbo), ''fit'')','Label','Fit to [(-0.5;-0.5)(0.5;0.5)]','Sep','on');

h = uimenu('Parent',hIM,'Label','Edge detect','Sep','on');
h2 = uimenu('Parent',h,'Label','Canny');
uimenu('Parent',h2,'Callback','mirone(''ImageEdgeDetect_CB'',guidata(gcbo),''Vec'')','Label','Vector');
uimenu('Parent',h2,'Callback','mirone(''ImageEdgeDetect_CB'',guidata(gcbo),''Ras'')','Label','Raster');
h2 = uimenu('Parent',h,'Label','SUSAN');
uimenu('Parent',h2,'Callback','mirone(''ImageEdgeDetect_CB'',guidata(gcbo),''SUSvec'')','Label','Vector');
uimenu('Parent',h2,'Callback','mirone(''ImageEdgeDetect_CB'',guidata(gcbo),''SUSras'')','Label','Raster');

h = uimenu('Parent',hIM,'Label','Features detection');
uimenu('Parent',h,'Callback','mirone(''ImageEdgeDetect_CB'',guidata(gcbo),''Lines'')','Label','Lines');
uimenu('Parent',h,'Callback','mirone(''ImageEdgeDetect_CB'',guidata(gcbo),''Rect'')','Label','Rectangles');
uimenu('Parent',h,'Callback','mirone(''ImageEdgeDetect_CB'',guidata(gcbo),''Circles'')','Label','Circles');
uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''Corners'')','Label','Good features to track');

uimenu('Parent',hIM,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''morph-img'')','Label','Image morphology');

uimenu('Parent',hIM,'Callback','mirone(''ImageSegment_CB'',guidata(gcbo))','Label','Image segmentation (Mean shift)','Sep','on');
uimenu('Parent',hIM,'Callback','floodfill(gcf)','Label','Shape detector')
uimenu('Parent',hIM,'Callback','mpaint(gcf)','Label','Paint Brush');
uimenu('Parent',hIM,'Callback','classificationfig(gcf);','Label','K-means classification');
uimenu('Parent',hIM,'Callback','imageresize(gcf)','Label','Image resize','Sep','on');
uimenu('Parent',hIM,'Callback','thresholdit(gcf)','Label','Binarize Image');
uimenu('Parent',hIM,'Callback','masker(guidata(gcbo))','Label','Mask Image');
uimenu('Parent',hIM,'Callback','mirone(''RotateTool_CB'',guidata(gcbo),''image'')','Label','Image rotation');

h = uimenu('Parent',hIM,'Label','Image mode');
uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''toRGB'')','Label','RGB truecolor','Tag','ImModRGB');
uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''8-bit'')','Label','8-bit color','Tag','ImMod8cor');
uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''gray'')','Label','Gray scale','Tag','ImMod8gray');
uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''bw'')','Label','Black and White','Tag','ImModBW');
uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''neg'')','Label','Negative','Tag','ImModNeg');
uimenu('Parent',h,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''negBW'')','Label','Negative BW','Tag','ImModNegBW');
uimenu('Parent',h,'Callback','mirone(''ImageResetOrigImg_CB'',guidata(gcbo))','Label','Original Image','Sep','on');

% ------------ Image filters _______ TO BE CONTINUED
h = uimenu('Parent',hIM,'Label','Filters','Sep','on');
uimenu('Parent',h,'Callback','filter_funs(guidata(gcbo),''SUSAN'');','Label','Smooth (SUSAN)');
uimenu('Parent',h,'Callback','filter_funs(guidata(gcbo),''Median'');','Label','Median (3x3)');
uimenu('Parent',h,'Callback','filter_funs(guidata(gcbo),''Adaptive'');','Label','Adaptive Median (7x7)');
uimenu('Parent',h,'Callback','filter_funs(guidata(gcbo),''STD'');','Label','STD (3x3)');
uimenu('Parent',h,'Callback','filter_funs(guidata(gcbo),''Min'');','Label','Min (3x3)');
uimenu('Parent',h,'Callback','filter_funs(guidata(gcbo),''Max'');','Label','Max (3x3)');
uimenu('Parent',h,'Callback','filter_funs(guidata(gcbo),''range'');','Label','Range (3x3)');
uimenu('Parent',hIM,'Callback','mirone(''DigitalFilt_CB'',guidata(gcbo),''image'')','Label','Digital Filtering Tool');
uimenu('Parent',hIM,'Callback','mirone(''GridToolsSectrum_CB'',guidata(gcbo), ''Allopts'')','Label','FFT Spectrum');

h = uimenu('Parent',hIM,'Label','Image Enhance','Sep','on');
uimenu('Parent',h,'Callback','image_enhance(gcf)','Label','1 - Indexed and RGB');
uimenu('Parent',h,'Callback','image_adjust(gcf)','Label', '2 - Indexed only');
uimenu('Parent',h,'Callback','ice_m(gcf,''space'',''rgb'')','Label','Image Color Editor (Indexed and RGB)');
uimenu('Parent',hIM,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''RGBexp'')','Label','Explore RGB');

h = uimenu('Parent',hIM,'Label','Register Image','Sep','on');
uimenu('Parent',h,'Callback','aux_funs(''togCheck'',gcbo)','Label','Activate Image-to-Image/Map GCP Tool','Tag','GCPtool');
uimenu('Parent',h,'Callback','mirone(''DrawLine_CB'',guidata(gcbo),''GCPpline'')','Label','Draw GCPoints');
uimenu('Parent',h,'Callback','mirone(''DrawLine_CB'',guidata(gcbo),''GCPimport'')','Label','Import GCPoints');
uimenu('Parent',h,'Callback','mirone(''DrawLine_CB'',guidata(gcbo),''GCPmemory'')',...
	'Tag','GCPmemory','Label','Plot in memory GCPs','Vis','off');  % To GDAL imported file with GCPs
uimenu('Parent',hIM,'Callback','grid_calculator(gcf)','Label','Bands Arithmetic','Sep','on');
uimenu('Parent',hIM,'Callback','bands_list(gcf)','Label','Load Bands','Sep','on');

%% --------------------------- TOOLS ------------------------------------
hTL = uimenu('Parent',H1,'Label','Tools','Tag','Tools');
h = uimenu('Parent',hTL,'Label','Extract Profile');
uimenu('Parent',h,'Callback','mirone(''ExtractProfile_CB'',guidata(gcbo))','Label','Static');
uimenu('Parent',h,'Callback','mirone(''ExtractProfile_CB'',guidata(gcbo),''dynamic'')','Label','Dynamic');

h = uimenu('Parent',hTL,'Label','Measure','Sep','on');
uimenu('Parent',h,'Callback','mirone(''ToolsMeasure_CB'',guidata(gcbo),''LLength'')','Label','Distance','Tag','ToolsMeasureDist');
uimenu('Parent',h,'Callback','mirone(''ToolsMeasure_CB'',guidata(gcbo),''Azim'')','Label','Azimuth');
uimenu('Parent',h,'Callback','mirone(''ToolsMeasure_CB'',guidata(gcbo),''Area'')','Label','Area');
uimenu('Parent',h,'Callback','mirone(''ToolsMeasureAreaPerCor_CB'',guidata(gcbo))','Label','Area per color');

h = uimenu('Parent',hTL,'Label','Multi-beam planing','Tag','MBplan','Sep','on');		hVG(kv) = h;	kv = kv + 1;
uimenu('Parent',h,'Callback','mirone(''ToolsMBplaningStart_CB'',guidata(gcbo))','Label','Start track');
uimenu('Parent',h,'Callback','mirone(''ToolsMBplaningImport_CB'',guidata(gcbo))','Label','Import track');

uimenu('Parent',hTL,'Callback','ecran','Label','X,Y grapher','Sep','on');
uimenu('Parent',hTL,'Callback','aquamoto(guidata(gcbo))','Label','Aquamoto Viewer','Sep','on');
uimenu('Parent',hTL,'Callback','empilhador(guidata(gcbo))','Label','Empilhador');
uimenu('Parent',hTL,'Callback','slices(guidata(gcbo))','Label','Slices');
uimenu('Parent',hTL,'Callback','sat_orbits(guidata(gcbo))','Label','Satellite Orbits');
uimenu('Parent',hTL,'Callback','tiles_tool(guidata(gcbo))','Label','Tiling Tool','Sep','on');
hVG(kv) = uimenu('Parent',hTL,'Callback','diluvio(guidata(gcbo))','Label','Noe Diluge','Sep','on');		kv = kv + 1;
uimenu('Parent',hTL,'Callback','travel(guidata(gcbo))','Label','Mirone Travel','Sep','on');
uimenu('Parent',hTL,'Callback','world_is_not_round_enough(guidata(gcbo))','Label','World is not (round) enough','Sep','on');
uimenu('Parent',hTL,'Callback','mk_movie_from_list(guidata(gcbo))', 'Label','Make movie from image list','Sep','on');

h = uimenu('Parent',hTL,'Label','Misc Tools','Sep','on');
uimenu('Parent',h,'Callback','cartas_militares(guidata(gcbo),''nikles'')','Label','LIDAR2011 PT')
uimenu('Parent',h,'Callback','cartas_militares(guidata(gcbo))','Label','Cartas Militares')
uimenu('Parent',h,'Callback','obj_template_detect(gcf)','Label','Object detection','Sep','on');
uimenu('Parent',h,'Callback','vitrinite','Label','Vitrinite','Sep','on');
uimenu('Parent',h,'Callback','mesher_helper(gca)','Label','Nesting meshes','Sep','on');

uimenu('Parent',hTL,'Callback','run_cmd(guidata(gcbo))','Label','Run ML Command','Sep','on');
uimenu('Parent',hTL,'Callback','line_operations(guidata(gcbo))','Label','Vector Operations','Tag','lineOP');
%uimenu('Parent',hTL,'Callback','autofaults(guidata(gcbo))','Label','Auto falhas','Sep','on');

%% --------------------------- DRAW ------------------------------------
hDR = uimenu('Parent',H1,'Label','Draw','Tag','Draw');
uimenu('Parent',hDR,'Callback','mirone(''DrawLine_CB'',guidata(gcbo))','Label','Draw line','Tag','ctrLine', 'Accelerator','l');
uimenu('Parent',hDR,'Callback','mirone(''DrawLine_CB'',guidata(gcbo),''spline'')','Label','Draw interpolating spline');
uimenu('Parent',hDR,'Callback','mirone(''DrawLine_CB'',guidata(gcbo),''freehand'')','Label','Freehand draw');
uimenu('Parent',hDR,'Callback','mirone(''DrawClosedPolygon_CB'',guidata(gcbo),[])','Label','Draw closed polygon');

h = uimenu('Parent',hDR,'Label','Draw circle','Sep','on');
uimenu('Parent',h,'Callback','mirone(''DrawGeogCircle_CB'',guidata(gcbo))','Label','Geographical circle');
uimenu('Parent',h,'Callback','mirone(''DrawGeogCircle_CB'',guidata(gcbo),''gcirc'')','Label','Great circle arc');
uimenu('Parent',h,'Callback','mirone(''DrawGeogCircle_CB'',guidata(gcbo),''cartCirc'')','Label','Cartesian circle');
uimenu('Parent',hDR,'Callback','mirone(''DrawClosedPolygon_CB'',guidata(gcbo),''rectangle'')','Label','Draw rectangle');
uimenu('Parent',hDR,'Callback','mirone(''Draw_CB'',guidata(gcbo),''Vector'')','Label','Draw vector');

h = uimenu('Parent',hDR,'Label','Draw symbol');
uimenu('Parent',h,'Callback','mirone(''Draw_CB'',guidata(gcbo),''Symbol'',''o'')','Label','Circle');
uimenu('Parent',h,'Callback','mirone(''Draw_CB'',guidata(gcbo),''Symbol'',''s'')','Label','Square');
uimenu('Parent',h,'Callback','mirone(''Draw_CB'',guidata(gcbo),''Symbol'',''^'')','Label','Triangle');
uimenu('Parent',h,'Callback','mirone(''Draw_CB'',guidata(gcbo),''Symbol'',''p'')','Label','Star');
uimenu('Parent',h,'Callback','mirone(''Draw_CB'',guidata(gcbo),''Symbol'',''x'')','Label','Cross');

uimenu('Parent',hDR,'Callback','mirone(''Draw_CB'',guidata(gcbo),''Text'')','Label','Insert text');
hVG(kv) = uimenu('Parent',hDR,'Callback','mirone(''DrawContours_CB'',guidata(gcbo))',...
'Label','Contours (automatic)','Sep','on','Tag','Contours_a');		kv = kv + 1;
hVG(kv) = uimenu('Parent',hDR,...
'Callback','mirone(''DrawContours_CB'',guidata(gcbo),''gui'')','Label','Contours','Tag','Contours_i');	kv = kv + 1;

uimenu('Parent',hDR,'Callback','makescale(gca,gcbo)','Label','Map Scale','Sep','on');

%% --------------------------- Geography ---------------------------------
hDS = uimenu('Parent',H1,'Label','Geography','Tag','Geography');
h = uimenu('Parent',hDS,'Label','Plot coastline','Tag','VoidDatasetsCoastLine');

uimenu('Parent',h,'Callback','datasets_funs(''CoastLines'',guidata(gcbo),''l'')','Label','Low resolution','Tag','CoastLineLow');
uimenu('Parent',h,'Callback','datasets_funs(''CoastLines'',guidata(gcbo),''i'')','Label','Intermediate resolution','Tag','CoastLineInterm');
uimenu('Parent',h,'Callback','datasets_funs(''CoastLines'',guidata(gcbo),''h'')','Label','High resolution','Tag','CoastLineHigh');
uimenu('Parent',h,'Callback','datasets_funs(''CoastLines'',guidata(gcbo),''f'')','Label','Full resolution','Tag','CoastLineFull');

h2 = uimenu('Parent',hDS,'Label','Plot political boundaries','Tag','VoidDatasetsPB');
h = uimenu('Parent',h2,'Label','National boundaries');

uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''1'',''l'')','Label','Low resolution','Tag','PBLow');
uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''1'',''i'')','Label','Intermediate resolution','Tag','PBInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''1'',''h'')','Label','High resolution','Tag','PBHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''1'',''f'')','Label','Full resolution','Tag','PBFull');

h = uimenu('Parent',h2,'Label','State boundaries (US)');

uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''2'',''l'')','Label','Low resolution','Tag','PBLow');
uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''2'',''i'')','Label','Intermediate resolution','Tag','PBInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''2'',''h'')','Label','High resolution','Tag','PBHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''2'',''f'')','Label','Full resolution','Tag','PBFull');

h = uimenu('Parent',h2,'Label','All boundaries');

uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''a'',''l'')','Label','Low resolution','Tag','PBLow');
uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''a'',''i'')','Label','Intermediate resolution','Tag','PBInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''a'',''h'')','Label','High resolution','Tag','PBHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Political'',guidata(gcbo),''a'',''f'')','Label','Full resolution','Tag','PBFull');

h2 = uimenu('Parent',hDS,'Label','Plot rivers','Tag','VoidDatasetsRivers');
h = uimenu('Parent',h2,'Label','Permanent major rivers');

uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''1'',''l'')','Label','Low resolution','Tag','RiversLow');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''1'',''i'')','Label','Intermediate resolution','Tag','RiversInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''1'',''h'')','Label','High resolution','Tag','RiversHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''1'',''f'')','Label','Full resolution','Tag','RiversFull');

h = uimenu('Parent',h2,'Label','Additional major rivers');

uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''2'',''l'')','Label','Low resolution','Tag','RiversLow');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''2'',''i'')','Label','Intermediate resolution','Tag','RiversInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''2'',''h'')','Label','High resolution','Tag','RiversHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''2'',''f'')','Label','Full resolution','Tag','RiversFull');

h = uimenu('Parent',h2,'Label','Additional rivers');

uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''3'',''l'')','Label','Low resolution','Tag','RiversLow');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''3'',''i'')','Label','Intermediate resolution','Tag','RiversInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''3'',''h'')','Label','High resolution','Tag','RiversHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''3'',''f'')','Label','Full resolution','Tag','RiversFull');

h = uimenu('Parent',h2,'Label','Intermittent rivers - major');

uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''5'',''l'')','Label','Low resolution','Tag','RiversLow');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''5'',''i'')','Label','Intermediate resolution','Tag','RiversInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''5'',''h'')','Label','High resolution','Tag','RiversHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''5'',''f'')','Label','Full resolution','Tag','RiversFull');

h = uimenu('Parent',h2,'Label','Intermittent rivers - additional');

uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''6'',''l'')','Label','Low resolution','Tag','RiversLow');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''6'',''i'')','Label','Intermediate resolution','Tag','RiversInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''6'',''h'')','Label','High resolution','Tag','RiversHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''6'',''f'')','Label','Full resolution','Tag','RiversFull');

h = uimenu('Parent',h2,'Label','Intermittent rivers - minor');

uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''7'',''l'')','Label','Low resolution','Tag','RiversLow');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''7'',''i'')','Label','Intermediate resolution','Tag','RiversInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''7'',''h'')','Label','High resolution','Tag','RiversHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''7'',''f'')','Label','Full resolution','Tag','RiversFull');

h = uimenu('Parent',h2,'Label','All rivers and canals');

uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''a'',''l'')','Label','Low resolution','Tag','RiversLow');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''a'',''i'')','Label','Intermediate resolution','Tag','RiversInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''a'',''h'')','Label','High resolution','Tag','RiversHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''a'',''f'')','Label','Full resolution','Tag','RiversFull');

h = uimenu('Parent',h2,'Label','All permanent rivers');

uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''r'',''l'')','Label','Low resolution','Tag','RiversLow');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''r'',''i'')','Label','Intermediate resolution','Tag','RiversInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''r'',''h'')','Label','High resolution','Tag','RiversHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''r'',''f'')','Label','Full resolution','Tag','RiversFull');

h = uimenu('Parent',h2,'Label','All intermittent rivers');

uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''i'',''l'')','Label','Low resolution','Tag','RiversLow');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''i'',''i'')','Label','Intermediate resolution','Tag','RiversInterm');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''i'',''h'')','Label','High resolution','Tag','RiversHigh');
uimenu('Parent',h,'Callback','datasets_funs(''Rivers'',guidata(gcbo),''i'',''f'')','Label','Full resolution','Tag','RiversFull');

uimenu('Parent',hDS,'Callback','earthquakes(gcf);','Label','Global seismicity (1990-2009)','Sep','on');
uimenu('Parent',hDS,'Callback','datasets_funs(''Hotspots'',guidata(gcbo))','Label','Hotspot locations');
uimenu('Parent',hDS,'Callback','load_xyz(guidata(gcbo), ''nikles'', ''Isochrons'')','Label','Magnetic isochrons');
uimenu('Parent',hDS,'Callback','datasets_funs(''Volcanoes'',guidata(gcbo))','Label','Volcanoes');
uimenu('Parent',hDS,'Callback','datasets_funs(''Meteorite'',guidata(gcbo))','Label','Meteorite impacts');
uimenu('Parent',hDS,'Callback','datasets_funs(''Hydrothermal'',guidata(gcbo))','Label','Hydrothermal sites');
uimenu('Parent',hDS,'Callback','datasets_funs(''Tides'',guidata(gcbo))','Label','Tide Stations');
uimenu('Parent',hDS,'Callback','datasets_funs(''Maregs'',guidata(gcbo))','Label','Tides (download)');
uimenu('Parent',hDS,'Callback','earth_tides(gcf)','Label','Earth Tides');
uimenu('Parent',hDS,'Callback','load_xyz(guidata(gcbo), ''nikles'', ''FZ'')','Label','Fracture Zones');
uimenu('Parent',hDS,'Callback','datasets_funs(''Plate'',guidata(gcbo))','Label','Plate boundaries');

h = uimenu('Parent',hDS,'Label','Cities');
uimenu('Parent',h,'Callback','datasets_funs(''Cities'',guidata(gcbo),''major'')','Label','Major cities');
uimenu('Parent',h,'Callback','datasets_funs(''Cities'',guidata(gcbo),''other'')','Label','Other cities');

h = uimenu('Parent',hDS,'Label','DSDP/ODP/IODP sites');
uimenu('Parent',h,'Callback','datasets_funs(''ODP'',guidata(gcbo),''DSDP'')','Label','DSDP');
uimenu('Parent',h,'Callback','datasets_funs(''ODP'',guidata(gcbo),''ODP'')','Label','ODP');
uimenu('Parent',h,'Callback','datasets_funs(''ODP'',guidata(gcbo),''IODP'')','Label','IODP');
uimenu('Parent',h,'Callback','datasets_funs(''ODP'',guidata(gcbo),''ALL'')','Label','DSDP+ODP+IODP');

uimenu('Parent',hDS,'Callback','atlas(guidata(gcbo))','Label','Atlas','Tag','Atlas','Sep','on');
% uimenu('Parent',hDS,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''DayNight'')','Label','Day and Night','Sep','on');
% uimenu('Parent',hDS,'Callback','datasets_funs(''GTiles'', guidata(gcbo))','Label','GTiles Map','Sep','on');

%% --------------------------- Plates -------------------------------------
hP = uimenu('Parent',H1,'Label','Plates','Tag','Plates');
uimenu('Parent',hP,'Callback','plate_calculator','Label','Plate calculator');
uimenu('Parent',hP,'Callback','euler_stuff(gcf)','Label','Euler rotations');
uimenu('Parent',hP,'Callback','compute_euler(gcf)','Label','Compute Euler pole');
uimenu('Parent',hP,'Callback','demets_od(gcf)','Label','Apply (isoc) Outward Displacement');
uimenu('Parent',hP,'Callback','manual_pole_adjust(gcf)','Label','Manual adjust Euler pole');
uimenu('Parent',hP,'Callback','euler_poles_selector(gcf)','Label','Draw Circle about Euler pole');
uimenu('Parent',hP,'Callback','mirone(''DrawClosedPolygon_CB'',guidata(gcbo),''EulerTrapezium'')','Label','Draw Euler trapezium');
uimenu('Parent',hP,'Callback','datasets_funs(''ITRF'',guidata(gcbo))','Label','Plot ITRF2008 velocities');
uimenu('Parent',hP,'Callback','datasets_funs(''Plate'',guidata(gcbo))','Label','Plot Plate boundaries');
hVG(kv) = uimenu('Parent',hP,'Callback','mirone(''PlatesAgeLift_CB'',guidata(gcbo))','Label','Age Lift','Sep','on');	kv = kv + 1;
uimenu('Parent',hP,'Callback','rally_plater','Label','Rally Plater','Sep','on');

%% --------------------------- Mag/Grav -----------------------------------
hMG = uimenu('Parent',H1,'Label','Mag/Grav','Tag','MagGrav');

uimenu('Parent',hMG,'Callback','igrf_options(guidata(gcbo))','Label','IGRF calculator');
uimenu('Parent',hMG,'Callback','parker_stuff(''parker_direct'',gcf)','Label','Parker Direct');
uimenu('Parent',hMG,'Callback','parker_stuff(''parker_inverse'',gcf)','Label','Parker Inversion');
uimenu('Parent',hMG,'Callback','parker_stuff(''redPole'',gcf)','Label','Reduction to the Pole');
uimenu('Parent',hMG,'Callback','parker_stuff(''component'',gcf)','Label','Total field to Component');
uimenu('Parent',hMG,'Callback','microlev(gcf)','Label','Microleveling (anomaly grid)');
uimenu('Parent',hMG,'Callback','mirone(''line_levelling'',guidata(gcbo))','Label','Macroleveling');
%uimenu('Parent',hMG,'Callback','gravfft(gcf)','Label','GravFFT');
uimenu('Parent',hMG,'Callback','mirone(''GridToolsSectrum_CB'',guidata(gcbo), ''Allopts'')','Label','FFT tool');
uimenu('Parent',hMG,'Callback','telhometro(gcf)','Label','Vine-Mathiews Carpet');
uimenu('Parent',hMG,'Callback','load_xyz(guidata(gcbo), ''nikles'', ''Isochrons'')','Label','Magnetic isochrons');
h = uimenu('Parent',hMG,'Label','Custom isochrons', 'Tag','CustomIsoc');
uimenu('Parent',h,'Callback','load_xyz(guidata(gcbo), [], ''IsochronsC'')','Label','Open file');
uimenu('Parent',h,'Callback','isoc_selector(gcf)','Label','Interactive slection');
uimenu('Parent',hMG,'Callback','magbarcode','Label','Magnetic Bar Code','Sep','on');

h = uimenu('Parent',hMG,'Label','Import *.gmt/*.nc files(s)','Sep','on');
uimenu('Parent',h,'Callback','mirone(''GeophysicsImportGmtFile_CB'',guidata(gcbo),''single'')','Label','Single *.gmt/*.nc file');
uimenu('Parent',h,'Callback','mirone(''GeophysicsImportGmtFile_CB'',guidata(gcbo),''list'')','Label','List of files');
hVG(kv) = uimenu('Parent',hMG,'Callback','gmtedit','Label','gmtedit');	kv = kv + 1;

%% --------------------------- Seismology -------------------------------
hS = uimenu('Parent',H1,'Label','Seismology','Tag','Seismology');

uimenu('Parent',hS,'Callback','earthquakes(gcf,''external'');','Label','Seismicity');
uimenu('Parent',hS,'Callback','focal_meca(gcf)','Label','Focal mechanisms');
uimenu('Parent',hS,'Callback','meca_studio','Label','Focal Mechanisms demo');
uimenu('Parent',hS,'Callback','globalcmt(gcf)','Label','CMT Catalog (Web download)');
uimenu('Parent',hS,'Callback','earthquakes(gcf);','Label','Global seismicity (1990-2009)');
uimenu('Parent',hS,'Callback','usgs_recent_seismicity(gcf);','Label','USGS recent seismicity');
uimenu('Parent',hS,'Callback','ground_motion(guidata(gcbo))','Label','Ground motions');
h = uimenu('Parent',hS,'Label','Elastic deformation','Sep','on');
uimenu('Parent',h,'Callback','mirone(''DrawLine_CB'',guidata(gcbo),''FaultTrace'')','Label','Draw Fault');
uimenu('Parent',h,'Callback','load_xyz(guidata(gcbo), [], ''FaultTrace'')','Label','Import Trace Fault');
uimenu('Parent',h,'Callback','fault_models(guidata(gcbo))', 'Label','Import Model Slip');

%% --------------------------- Tsunamis -------------------------------
hT = uimenu('Parent',H1,'Label','Tsunamis','Tag','Tsunamis');		hVG(kv) = hT;		kv = kv + 1;

h = uimenu('Parent',hT,'Label','Tsunami Travel Time','Sep','on');
uimenu('Parent',h,'Callback','tsu_funs(''TTT'',guidata(gcbo))','Label','Plot point source');
uimenu('Parent',h,'Callback','tsu_funs(''TTT'',guidata(gcbo),''line'')','Label','Draw Fault source');
uimenu('Parent',h,'Callback','tsu_funs(''TTT'',guidata(gcbo),''load'')','Label','Import maregraphs and time');
uimenu('Parent',h,'Callback','tsu_funs(''TTT'',guidata(gcbo),''compute'')','Label','Compute','Sep','on');

h = uimenu('Parent',hT,'Label','Swan');
uimenu('Parent',h,'Callback','tsu_funs(''SwanCompute'',guidata(gcbo))','Label','Compute');
uimenu('Parent',h,'Callback','load_xyz(guidata(gcbo), [], ''AsMaregraph'')','Label','Import Stations','Sep','on');
uimenu('Parent',h,'Callback','mirone(''GeophysicsSwanPlotStations_CB'',guidata(gcbo))','Label','Plot Stations');
uimenu('Parent',h,'Callback','tsu_funs(''SwanGridBorder'',guidata(gcbo))','Label','Stations on grid borders');
uimenu('Parent',hT,'Callback','tintol(guidata(gcbo))','Label','TINTOL');
uimenu('Parent',hT,'Callback','mirone(''GeophysicsSwanPlotStations_CB'',guidata(gcbo))','Label','Plot Stations', 'Vis','off', 'Sep','on');
uimenu('Parent',hT,'Callback','load_xyz(guidata(gcbo), [], ''AsMaregraph'')','Label','Import Stations', 'Vis','off');

uimenu('Parent',hT,'Callback','aquamoto(guidata(gcbo))','Label','Aquamoto Viewer','Sep','on');

%% --------------------------- Met/Oce ------------------------------------
hMO = uimenu('Parent',H1,'Label','Met/Oce','Tag','MetOce');
uimenu('Parent',hMO,'Callback','argo_floats(gcf)', 'Label','Show ARGO buoys');
uimenu('Parent',hMO,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''WOA'')', 'Label','World Ocean Atlas');
uimenu('Parent',hMO,'Callback','tmd_osu(guidata(gcbo))', 'Label','Tidal Model Driver (OSU)');

%% --------------------------- GMT ----------------------------------------
hGMT = uimenu('Parent',H1,'Label','GMT','Tag','GMT');		hVG(kv) = hGMT;		kv = kv + 1;

uimenu('Parent',hGMT,'Callback','grdfilter_mir(guidata(gcbo))','Label','grdfilter');
%uimenu('Parent',hGMT,'Callback','regional_residual(guidata(gcbo))','Label','Regional-Residual');
uimenu('Parent',hGMT,'Callback','grdgradient_mir(guidata(gcbo))','Label','grdgradient');
uimenu('Parent',hGMT,'Callback','grdsample_mir(guidata(gcbo))','Label','grdsample');
uimenu('Parent',hGMT,'Callback','grdtrend_mir(guidata(gcbo))','Label','grdtrend');
uimenu('Parent',hGMT,'Callback','grdlandmask_win(guidata(gcbo))','Label','grdlandmask');
uimenu('Parent',hGMT,'Callback','geog_calculator(guidata(gcbo))','Label','grd|map project');

h = uimenu('Parent',hGMT,'Label','Interpolate');
uimenu('Parent',h,'Callback','griding_mir(gcf,''surface'');', 'Label','Minimum curvature');
uimenu('Parent',h,'Callback','griding_mir(gcf,''nearneighbor'');', 'Label','Near neighbor');

%% --------------------------- GRID TOOLS --------------------------------
hGT = uimenu('Parent',H1,'Label','Grid Tools','Tag','GridTools');		hVG(kv) = hGT;

uimenu('Parent',hGT,'Callback','grid_calculator(gcf)','Label','grid calculator');
h = uimenu('Parent',hGT,'Label','Contours','Sep','on');
uimenu('Parent',h,'Callback','mirone(''DrawContours_CB'',guidata(gcbo))','Label','Automatic','Tag','Contours_a');
uimenu('Parent',h,'Callback','mirone(''DrawContours_CB'',guidata(gcbo),''gui'')','Label','Contour Tool','Tag','Contours_i');

uimenu('Parent',hGT,'Callback','ml_clip(guidata(gcbo))','Label','Clip Grid');
uimenu('Parent',hGT,'Callback','mirone(''ImageCrop_CB'',guidata(gcbo),[],''CropaGrid'')','Label','Crop Grid');
uimenu('Parent',hGT,'Callback','masker(guidata(gcbo))','Label','Mask Grid');
uimenu('Parent',hGT,'Callback','mirone(''RotateTool_CB'',guidata(gcbo),''grid'')','Label','Rotate Grid');
uimenu('Parent',hGT,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''TransplantGrid'')','Label','Transplant 2nd Grid');
%uimenu('Parent',hGT,'Callback','transplant_grid(guidata(gcbo))','Label','Transplant 2nd Grid');
uimenu('Parent',hGT,'Callback','mirone(''GridToolsHistogram_CB'',guidata(gcbo))','Label','Histogram');
h = uimenu('Parent',hGT,'Label','Holes (NaNs)', 'Tag','haveNaNs');
uimenu('Parent',h,'Callback','mirone(''GridToolsGridMask_CB'',guidata(gcbo))','Label','Write Mask');
uimenu('Parent',h,'Callback','inpaint_nans(guidata(gcbo))','Label','Inpaint NaNs');
uimenu('Parent',h,'Callback','mirone(''ImageEdgeDetect_CB'',guidata(gcbo),''apalpa'')','Label','Digitize holes');
uimenu('Parent',h,'Callback','mirone(''GridToolsFindHoles_CB'',guidata(gcbo))','Label','Find holes');

uimenu('Parent',hGT,'Callback','mirone(''Transfer_CB'',guidata(gcbo),''morph-grd'')','Label','Morphology');
uimenu('Parent',hGT,'Callback','mirone(''DigitalFilt_CB'',guidata(gcbo),''grid'')','Label','Digital filtering Tool');
uimenu('Parent',hGT,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''fract'')','Label','Fractal field','Sep','on');

h = uimenu('Parent',hGT,'Label','Hammer this grid','Sep','on');
uimenu('Parent',h,'Callback','escadeirar(guidata(gcbo))','Label','Rice-field Grid');
uimenu('Parent',h,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''scale'')','Label','Rescale');
uimenu('Parent',h,'Callback','mirone(''GridToolsPadd2Const_CB'',guidata(gcbo))','Label','Pad to zero');

h = uimenu('Parent',hGT,'Label','Spectrum');
uimenu('Parent',h,'Callback','mirone(''GridToolsSectrum_CB'',guidata(gcbo), ''Amplitude'')','Label','Amplitude spectrum');
uimenu('Parent',h,'Callback','mirone(''GridToolsSectrum_CB'',guidata(gcbo), ''Power'')','Label','Power spectrum');
uimenu('Parent',h,'Callback','mirone(''GridToolsSectrum_CB'',guidata(gcbo), ''Autocorr'')','Label','Autocorrelation');

uimenu('Parent',hGT,'Callback','mirone(''GridToolsSmooth_CB'',guidata(gcbo))','Label','Spline Smooth','Sep','on');

h = uimenu('Parent',hGT,'Label','SDG');
uimenu('Parent',h,'Callback','mirone(''GridToolsSDG_CB'',guidata(gcbo),''positive'')','Label','Positive');
uimenu('Parent',h,'Callback','mirone(''GridToolsSDG_CB'',guidata(gcbo),''negative'')','Label','Negative');
uimenu('Parent',h,'Callback','mirone(''GridToolsSDG_CB'',guidata(gcbo),[])','Label','Both');

h2 = uimenu('Parent',hGT,'Label','Terrain Modeling','Sep','on');
h = uimenu('Parent',h2,'Label','Slope');
uimenu('Parent',h,'Callback','mirone(''GridToolsSlope_CB'',guidata(gcbo),''degrees'');','Label','In degrees');
uimenu('Parent',h,'Callback','mirone(''GridToolsSlope_CB'',guidata(gcbo),''percent'');','Label','In percentage');

uimenu('Parent',h2,'Callback','mirone(''GridToolsSlope_CB'',guidata(gcbo),''aspect'');','Label','Aspect');
h = uimenu('Parent',h2,'Label','Directional derivative');
uimenu('Parent',h,'Callback','mirone(''GridToolsDirDerive_CB'',guidata(gcbo),''first'')','Label','First derivative');
uimenu('Parent',h,'Callback','mirone(''GridToolsDirDerive_CB'',guidata(gcbo),''second'')','Label','Second derivative');
uimenu('Parent',h2,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''sinks'')','Label','Fill sinks');
uimenu('Parent',h2,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''Multiscale'')','Label','Multi-scale Analysis');
uimenu('Parent',h2,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''Hypso'')','Label','Hypsometric curve', 'Sep', 'on');

% h = uimenu('Parent',hGT,'Label','River Tools','Sep','on');
% uimenu('Parent',h,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''hydro_flow'')','Label','Compute Flow');
% uimenu('Parent',h,'Callback','mirone(''TransferB_CB'',guidata(gcbo),''hydro_basin'')','Label','Compute drainage basin');

uimenu('Parent',hGT,'Label','Interpolate', 'Callback','griding_mir(gcf,''surface'');', 'Sep','on');

h2 = uimenu('Parent',hGT,'Label','SRTM tools','Sep','on');

h = uimenu('Parent',h2,'Label','SRTM mosaic');
uimenu('Parent',h,'Callback','srtm_tool','Label','SRTM 3sec');
uimenu('Parent',h,'Callback','srtm_tool(''srtm1'')','Label','SRTM 1sec');
uimenu('Parent',h,'Callback','srtm_tool(''srtm30'')','Label','SRTM30');
uimenu('Parent',h2,'Callback','mirone(''GridToolsSaveAsSRTM_CB'',guidata(gcbo))','Label','Save as SRTM');

%uimenu('Parent',hGT,'Callback','mirone(''GridToolsMesher_CB'',guidata(gcbo))','Label','Mesher','Sep','on');
uimenu('Parent',hGT,'Callback','mirone(''ImageEdgeDetect_CB'',guidata(gcbo),''ppa'')','Label','Extract ridges/valleys','Sep','on');
%uimenu('Parent',hGT,'Callback','find_seamounts(guidata(gcbo))','Label','Find Seamounts');

%% --------------------------- PROJECTIONS -----------------------------
h = uimenu('Parent',H1,'Label','Projections','Tag','Projections');
projection_menu(H1, h, home_dir);
%uimenu('Parent',h,'Callback','geog_calculator(guidata(gcbo))','Label','Geographic Computator','Sep','on');
uimenu('Parent',h,'Callback','gdal_project(guidata(gcbo),[])','Label','Assign SRS');
uimenu('Parent',h,'Callback','vector_project(guidata(gcbo))','Label','Point projections','Sep','on');
uimenu('Parent',h,'Callback','geog_calculator(guidata(gcbo),''onlyGrid'')','Label','GMT project','Sep','on');
uimenu('Parent',h,'Callback','gdal_project(guidata(gcbo))','Label','GDAL project');

%% --------------------------- HELP ------------------------------------
h = uimenu('Parent',H1,'Label','Help','Tag','Help');
uimenu('Parent',h, 'Callback','aux_funs(''help'',guidata(gcbo))','Label','Mirone Help (v2.0)');
uimenu('Parent',h, 'Callback', @showGDALdrivers,'Label','List GDAL formats','Sep','on')
if (IamCompiled)
	uimenu('Parent',h, 'Callback', 'mirone(''TransferB_CB'',guidata(gcbo),''dump'')','Label','Print RAM fragmentation','Sep','on')
	uimenu('Parent',h, 'Callback', 'mirone(''TransferB_CB'',guidata(gcbo),''lasterr'')','Label','Debug - Print last error')
	uimenu('Parent',h, 'Callback', 'mirone(''TransferB_CB'',guidata(gcbo),''sharedir'')','Label','Debug - Print GMT_SHAREDIR')
 	uimenu('Parent',h, 'Callback', 'test_bots','Label','Tests - Run some tests')
	uimenu('Parent',h, 'Callback', 'mirone(''TransferB_CB'',guidata(gcbo),''update'')','Label','Check for updates','Sep','on')
end
%uimenu('Parent',h, 'Callback', 'update_gmt(guidata(gcbo))','Label','Update your GMT5','Sep','on')
uimenu('Parent',h, 'Callback',['mirone(''FileOpenWebImage_CB'',guidata(gcbo),',...
	' ''http://www2.clustrmaps.com/stats/maps-clusters/w3.ualg.pt-~jluis-mirone-world.jpg'',''nikles'');'],'Label','See visitors map','Sep','on');
uimenu('Parent',h, 'Callback','about_box(guidata(gcbo),''Mirone Last modified at 01 Mar 2021'',''3.0.1'')','Label','About','Sep','on');

%% --------------------------- Build HANDLES and finish things here
	handles = guihandles(H1);
	handles.version7 = version7;			% If == 1 => R14 or latter
	handles.IamCompiled = IamCompiled;		% If == 1 than we know that we are dealing with a compiled (V3) version
	handles.IAmAMac = IAmAMac;
	handles.IAmOctave = IAmOctave;			% To know if we are runing under Octave
	if (version7),  set(H1,'Pos',[pos(1:3) 1]);    end     % Adjust for the > R13 bugginess
	handles.RecentF = handles.RecentF(end:-1:1);  % Inverse creation order so that newest files show on top of the list
	handles.noVGlist = hVG;					% List of ui handles that will not show when "not valid grid"
	handles.mirVersion = [2 0 0];			% Something like [major minor revision]
	move2side(H1,'north');					% Reposition the window on screen
% 	set(H1,'Vis','on');

% --------------------------------------------------------------------------------------------------
% We need this function also when the pixval_stsbar get stucked
function refresca(obj, evt)
	hFig = get(0,'CurrentFigure');
    set(hFig,'Pointer','arrow');
	%set(hFig,'Renderer','painters', 'RendererMode','auto')
	refresh(hFig)

% --------------------------------------------------------------------------------------------------
function showGDALdrivers(hObj, evt)
	att   = gdalread('','-M','-D');
	long  = {att.Driver.DriverLongName}';
	short = {att.Driver.DriverShortName}';
	list  = cat(2,short,long);
    tableGUI('array',list,'ColWidth',[70 220],'ColNames',{'Short' 'Long Format Name'},...
        'FigName','Potentialy Available GDAL formats','RowNumbers','y','MAX_ROWS',20,'modal','','RowHeight',24);

% -----------------------------------------------------------------------------
function figure1_KeyPressFcn(hObj, event)
	handles = guidata(hObj);
	if (handles.no_file),	return,		end
	cc = get(hObj,'CurrentCharacter');
	if (isempty(cc)),		return,		end		% HTF can this happen? But I already saw it happen
	if (cc == '+' || cc == '[')			% Lazy undocumented keys for convinience when using English keyboards
		zoom_j(hObj,2,[]);
	elseif (cc == '-' || cc == '/')
		zoom_j(hObj,0.5,[]);
	end
	hSliders = getappdata(handles.axes1,'SliderAxes');
	if (~isempty(hSliders) && strcmp( get(hSliders(1),'Vis'),'on' ))	% If (1) is visible so is the other
		CK = get(hObj,'CurrentKey');
		if (strcmp(CK,'rightarrow') || strcmp(CK,'leftarrow'))
			SS = get(hSliders(1),'SliderStep');			val = get(hSliders(1),'Value');
			if (CK(1) == 'r'),		newVal = min(val + SS(1), 1);	% I know that imscroll_j sliders are [0 1]
			else,					newVal = max(0, val - SS(1));
			end
			set(hSliders(1),'Value', newVal)
			imscroll_j(handles.axes1,'SetSliderHor')
		elseif (strcmp(CK,'uparrow') || strcmp(CK,'downarrow'))
			SS = get(hSliders(2),'SliderStep');			val = get(hSliders(2),'Value');
			if (CK(1) == 'u'),		newVal = min(val + SS(1), 1);	% I know that imscroll_j sliders are [0 1]
			else,					newVal = max(0, val - SS(1));
			end
			set(hSliders(2),'Value', newVal)
			imscroll_j(handles.axes1,'SetSliderVer')
		end
	end

% --------------------------------------------------------------------
function figure1_ResizeFcn(hObj, event)
	handles = guidata(hObj);
	if (isempty(handles)),      return,     end
	screen = get(0,'ScreenSize');	    pos = get(handles.figure1,'Pos');
	if (pos(1) == 1 && isequal(screen(3), pos(3)))	% Do not allow figure miximizing
		oldSize = handles.oldSize(1,:);
		if (oldSize(4) == 0),	oldSize(4) = 1;		end		% Old R13 puts it to 0
		set(handles.figure1,'Pos', oldSize)
	else
		hSliders = getappdata(handles.axes1,'SliderAxes');
		if (~isempty(hSliders))		% Reposition the vertical slider so that its always out of image
			oldUnit = get(handles.axes1, 'Units');	set(handles.axes1, 'Units', 'pixels');
			axPos = get(handles.axes1,'Pos');		sldT = 9;		% from sldT in resizetrue
			set(hSliders(2), 'Pos',[axPos(1)+axPos(3)+1 axPos(2) sldT axPos(4)+1])
			set(handles.axes1, 'Units', oldUnit);
		end
		handles.oldSize(1,:) = pos;		guidata(handles.figure1,handles)
	end

% -----------------------------------------------------------------------------
function figure1_CloseRequestFcn(hObj, event)
	handles = guidata(hObj);
	try		h = getappdata(handles.figure1,'dependentFigs');
	catch,	delete(gcf),	return
	end
	delete(handles.figure1);		delete(h(ishandle(h)))      % Delete also any eventual 'carra�as'
	if (isappdata(0, 'linkedStruct')),	rmappdata(0, 'linkedStruct'),	end		% Linked images use this container.
	FOpenList = handles.FOpenList;	fname = [handles.path_data 'mirone_pref.mat'];
	if (~handles.version7),			save(fname,'FOpenList','-append')   % Update the list for "Recent files"
	else,							save(fname,'FOpenList','-append', '-v6')
	end
