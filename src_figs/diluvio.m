function varargout = diluvio(varargin)
% Simulate the effect of sea-level variation on DEMs 

%	Copyright (c) 2004-2019 by J. Luis
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

% $Id$

	if isempty(varargin),	return,		end

	hObject = figure('Vis','off');
	diluvio_LayoutFcn(hObject);
	handles = guihandles(hObject);     
	handMir = varargin{1};
	move2side(handMir.figure1, hObject, 'right')

	Z = getappdata(handMir.figure1,'dem_z');
	if (~isempty(Z))
		handles.have_nans = handMir.have_nans;
		handles.z_min = handMir.head(5);
		handles.z_max = handMir.head(6);
		handles.z_min_orig = handles.z_min;
		handles.z_max_orig = handles.z_max;
	else
		warndlg('Grid was not stored in memory. Quiting','Warning')
		delete(hObject),	return
	end

	handles.hAxesMir = handMir.axes1;
	handles.hImgMir  = handMir.hImg;
	zz = scaleto8(Z,16);
	set(handles.hImgMir,'CData',zz,'CDataMapping','scaled')

	handles.water_color = [0 0 1];
	handles.hMirFig = handMir.figure1;
	cmap_orig = get(handles.hMirFig,'Colormap');
	dz = handles.z_max - handles.z_min;
	%cmap = interp1(1:size(cmap_orig,1),cmap_orig,linspace(1,size(cmap_orig,1),round(dz)));
	handles.cmap = cmap_orig;
	handles.cmap_original = cmap_orig;
	set(handles.figure1,'ColorMap',cmap_orig);      I = 1:length(cmap_orig);
	image(I(end:-1:1)','Parent',handles.axes1);
	set(handles.axes1,'YTick',[],'XTick',[]);

	% Add this figure handle to the carra�as list
	plugedWin = getappdata(handles.hMirFig,'dependentFigs');
	plugedWin = [plugedWin hObject];
	setappdata(handles.hMirFig,'dependentFigs',plugedWin);
	
	% Try to position this figure glued to the right of calling figure
	posThis = get(hObject,'Pos');
	posParent = get(handles.hMirFig,'Pos');
	ecran = get(0,'ScreenSize');
	xLL = posParent(1) + posParent(3) + 12;
	xLR = xLL + posThis(3);
	if (xLR > ecran(3))         % If figure is partially out, bring totally into screen
		xLL = ecran(3) - posThis(3);
	end
	yLL = (posParent(2) + posParent(4)/2) - posThis(4) / 2;
	set(hObject,'Pos',[xLL yLL posThis(3:4)])

	% Set the slider to the position corresponding to Z = 0, or z_min if grid doesn't cross 0
	sl_0 = 0;
	if (~(handMir.head(5) < 0 && handMir.head(6) > 0))		% OK, not the original intent but lets use it anyway
		sl_0 = handMir.head(5);
		set(handles.edit_zMin,'Str', ceil(sl_0))
		set(handles.edit_zMax,'Str', floor(handMir.head(6)))
		step = diff(handMir.head(5:6)) / 25;				% If it screws (i.e = 0), screws
		set(handles.edit_zStep,'Str', fix(step))
	end
	set(handles.slider_zeroLevel, 'Min',handles.z_min, 'Max',handles.z_max, 'Value',sl_0)
	set(handles.slider_zeroLevel,'SliderStep',[1 10]/dz)

	handles.n_water_ind = round((sl_0 - handles.z_min) / dz * size(handles.cmap,1));
	handles.cmap = [repmat(handles.water_color,handles.n_water_ind,1); handles.cmap_original(handles.n_water_ind+1:end,:)];
	set(handles.figure1,'ColorMap',handles.cmap)
	set(handles.hMirFig,'Colormap',handles.cmap)

	guidata(hObject, handles);	
	set(hObject,'Vis','on')
	if (nargout),	varargout{1} = hObject;		end

% -----------------------------------------------------------------------------------
function slider_zeroLevel_CB(hObject, handles)
	val = get(hObject,'Value');
	handles.n_water_ind = round((val - handles.z_min) / (handles.z_max - handles.z_min) * size(handles.cmap,1));
	handles.cmap = [repmat(handles.water_color,handles.n_water_ind,1); handles.cmap_original(handles.n_water_ind+1:end,:)];
	set(handles.figure1,'ColorMap',handles.cmap)
	set(handles.hMirFig,'ColorMap',handles.cmap)
	set(handles.text_zLevel,'String',num2str(val))
	guidata(handles.figure1,handles)

% -----------------------------------------------------------------------------------
function edit_zMin_CB(hObject, handles)
    xx = str2double(get(hObject,'String'));
    if (isnan(xx)),		set(hObject,'String','0'),	end

% -----------------------------------------------------------------------------------
function edit_zMax_CB(hObject, handles)
    xx = str2double(get(hObject,'String'));
    if (isnan(xx)),		set(hObject,'String','50'),	end

% -----------------------------------------------------------------------------------
function edit_zStep_CB(hObject, handles)
    xx = str2double(get(hObject,'String'));
    if (isnan(xx)),		set(hObject,'String','1'),	end

% -----------------------------------------------------------------------------------
function edit_frameInterval_CB(hObject, handles)
    xx = str2double(get(hObject,'String'));
    if (isnan(xx)),		set(hObject,'String','1'),	end

% -------------------------------------------------------------------------------------
function push_bgColor_CB(hObject, handles)
    c = uisetcolor;
    if (isequal(c, 0)),	return,		end
	handles.water_color = c;
	handles.cmap = [repmat(handles.water_color,handles.n_water_ind,1); handles.cmap_original(handles.n_water_ind+1:end,:)];
	set(handles.figure1,'ColorMap',handles.cmap)
	set(handles.hMirFig,'Colormap',handles.cmap)
    guidata(handles.figure1,handles)

% -----------------------------------------------------------------------------------
function push_run_CB(hObject, handles)
	zMin = round(str2double(get(handles.edit_zMin,'String')));
	zMax = floor(min(str2double(get(handles.edit_zMax,'String')), handles.z_max));
	dt = str2double(get(handles.edit_frameInterval,'String'));
	zStep = round(str2double(get(handles.edit_zStep,'String')));
	%zStep = zStep * sign(zMax);     % For going either up or down

	for (z = zMin:zStep:zMax)
		val_cor = round((z - handles.z_min) / (handles.z_max - handles.z_min) * length(handles.cmap));
		handles.cmap = [repmat(handles.water_color,val_cor,1); handles.cmap_original(val_cor+1:end,:)];
		set(handles.figure1,'ColorMap',handles.cmap)
		set(handles.hMirFig,'ColorMap',handles.cmap)
		set(handles.text_zLevel,'String',sprintf('%d',z))
		set(handles.slider_zeroLevel,'Value',z)
		pause(dt)
	end
    
%-------------------------------------------------------------------------------------
function figure1_KeyPressFcn(hObject, eventdata)
	if isequal(get(hObject,'CurrentKey'),'escape')
		delete(hObject);
	end


% --- Creates and returns a handle to the GUI figure. 
function diluvio_LayoutFcn(h1)

set(h1, 'Position',[520 456 155 344],...
'Color',get(0,'factoryUicontrolBackgroundColor'),...
'KeyPressFcn',{@figure1_KeyPressFcn},...
'MenuBar','none',...
'Name','NOE Deluge',...
'NumberTitle','off',...
'Resize','off',...
'HandleVisibility','callback',...
'Tag','figure1');

uicontrol('Parent',h1,'Position',[70 29 76 311],'Style','frame');

axes('Parent',h1, 'Units','pixels', 'Position',[30 29 30 311],...
'CameraPosition',[0.5 0.5 9.16025403784439],...
'Color',get(0,'defaultaxesColor'),...
'ColorOrder',get(0,'defaultaxesColorOrder'),...
'Tag','axes1');

uicontrol('Parent',h1, 'Position',[7 29 15 311],...
'BackgroundColor',[1 1 1],...
'Callback',@diluvio_uiCB,...
'Style','slider',...
'SliderStep',[0.001 0.05],...
'Tag','slider_zeroLevel');

uicontrol('Parent',h1, ...
'Units','characters',...
'Position',[1.8 0.384615384615385 14.2 1.23076923076923],...
'FontSize',10,...
'FontWeight','bold',...
'String','0',...
'Style','text',...
'Tag','text_zLevel');

uicontrol('Parent',h1, 'Position',[86 291 40 21],...
'BackgroundColor',[1 1 1],...
'Callback',@diluvio_uiCB,...
'String','0',...
'Style','edit',...
'TooltipString','Starting value of sea level',...
'Tag','edit_zMin');

uicontrol('Parent',h1, 'Position',[86 240 40 21],...
'BackgroundColor',[1 1 1],...
'Callback',@diluvio_uiCB,...
'String','50',...
'Style','edit',...
'TooltipString','Maximum height of flooding',...
'Tag','edit_zMax');

uicontrol('Parent',h1, 'Position',[91 189 30 21],...
'BackgroundColor',[1 1 1],...
'Callback',@diluvio_uiCB,...
'String','1',...
'Style','edit',...
'TooltipString','Height step for flooding',...
'Tag','edit_zStep');

uicontrol('Parent',h1, 'Position',[91 145 30 21],...
'BackgroundColor',[1 1 1],...
'Callback',@diluvio_uiCB,...
'String','1',...
'Style','edit',...
'TooltipString','Time interval between frames (seconds)',...
'Tag','edit_frameInterval');

uicontrol('Parent',h1, 'Position',[81 312 51 15],...
'HorizontalAlignment','left',...
'String','Start level',...
'Style','text');

uicontrol('Parent',h1, 'Position',[82 261 51 15],...
'HorizontalAlignment','left',...
'String','End level',...
'Style','text');

uicontrol('Parent',h1, 'Position',[91 211 31 15],...
'String','Dz',...
'Style','text');

uicontrol('Parent',h1, 'Position',[91 167 31 15],...
'String','Dt',...
'Style','text');

uicontrol('Parent',h1, 'Pos',[74 110 66 21],...
'Callback',@diluvio_uiCB,...
'String','Water color',...
'Tag','push_bgColor');

uicontrol('Parent',h1, 'Position',[86 70 40 21],...
'Callback',@diluvio_uiCB,...
'String','Run',...
'TooltipString','Run the Noe deluge',...
'Tag','push_run');

uicontrol('Parent',h1, 'Position',[86 42 48 15],...
'Enable','off',...
'String','Movie',...
'Style','checkbox',...
'TooltipString','Check this to create a movie',...
'Tag','checkbox_movie');

function diluvio_uiCB(hObject, eventdata)
% This function is executed by the callback and than the handles is allways updated.
	feval([get(hObject,'Tag') '_CB'],hObject, guidata(hObject));
