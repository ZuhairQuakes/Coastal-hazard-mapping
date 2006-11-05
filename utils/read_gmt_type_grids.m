function [handles,X,Y,Z,head] = read_gmt_type_grids(handles,fullname)

% Because GMT and Surfer share the .grd extension, find out which grid kind we are dealing with
X = [];     Y = [];     Z = [];     head = [];      % In case there is an error in this function
[fid, msg] = fopen(fullname, 'r');
if (fid < 0),   errordlg([fullname ': ' msg],'ERROR');
    return;
end
ID = fread(fid,4,'*char');      ID = ID';      fclose(fid);

tipo = 'GMT';                           % This is the default type
switch upper(ID)
    case {'DSBB' 'DSRB'}
        fullname = [fullname '=6'];
        handles.grdformat = 6;
        ID = 'CDF';                     % F... big lie, but no harm since the .grd=prefix was used
    case 'DSAA',    tipo = 'SRF_ASCII';
    case 'MODE',    tipo = 'ENCOM';
    case 'NLIG',    tipo = 'MAN_ASCII';
end

% See if the grid is on one of the other formats that GMT recognizes
if (strcmp(tipo,'GMT') && ~strcmp(ID(1:3),'CDF'))
    str = ['grdinfo ' fullname];
    [PATH,FNAME,EXT] = fileparts(fullname);
    [s,att] = mat_lyies(str,[handles.path_tmp FNAME '.' EXT '.info']);
    if ~(isequal(s,0))          % File could not be read
        errordlg([fullname ' : Is not a grid that GMT can read!'],'ERROR');
        return
    end
end

% if (strcmp(tipo,'GMT') && ~strcmp(ID(1:3),'CDF'))
%     errordlg([fullname ' : Is not a GMT netCDF grid!'],'ERROR');
%     return
% end
[handles,X,Y,Z,head] = read_grid(handles,fullname,tipo);

% ------------------------------------------------------------------------------------------
function [handles,X,Y,Z,head] = read_grid(handles,fullname,tipo)

if (isfield(handles,'ForceInsitu'))        % Other GUI windows may not know about 'ForceInsitu'
    if (handles.ForceInsitu),   opt_I = 'insitu';    % Use only in desperate cases.
    else                        opt_I = ' ';         end
else
    opt_I = ' ';
end
X = [];     Y = [];     Z = [];     head = [];

if (~strcmp(tipo,'GMT'))        % GMT files are open by the GMT machinerie
    [fid, msg] = fopen(fullname, 'r');
    if (fid < 0),   errordlg([fullname ': ' msg],'ERROR');  return;     end
end

if (strcmp(tipo,'GMT'))
    [X,Y,Z,head] = grdread_m(fullname,'single',opt_I);
    handles.image_type = 1;     handles.computed_grid = 0;
    handles.have_nans = grdutils(Z,'-N');
    if (head(10) == 2 || head(10) == 8 || head(10) == 16),   handles.was_int16 = 1;  end     % New output from grdread_m
    handles.grdname = fullname;     head(10) = [];
    if (head(7))            % Convert to grid registration
        head(1) = head(1) + head(8) / 2;        head(2) = head(2) - head(8) / 2;
        head(3) = head(3) + head(9) / 2;        head(4) = head(4) - head(9) / 2;
        head(7) = 0;
    end
elseif (strcmp(tipo,'SRF_ASCII'))   % Pretend that its a internaly computed grid (no reload)
    s = fgetl(fid);
    n_col_row = fscanf(fid,'%f',2);     x_min_max = fscanf(fid,'%f',2);
    y_min_max = fscanf(fid,'%f',2);     z_min_max = fscanf(fid,'%f',2);
    X = linspace(x_min_max(1),x_min_max(2),n_col_row(1));
    Y = linspace(y_min_max(1),y_min_max(2),n_col_row(2));
    Z = single(fscanf(fid,'%f',inf));   fclose(fid);
    Z = reshape(Z,n_col_row')';
    Z(Z >= 1e38) = NaN;
    handles.have_nans = grdutils(Z,'-N');
    dx = diff(x_min_max) / (n_col_row(1) - 1);
    dy = diff(y_min_max) / (n_col_row(2) - 1);
    head = [x_min_max' y_min_max' z_min_max' 0 dx dy];
    handles.image_type = 1;     handles.computed_grid = 1;    handles.grdname = [];
elseif (strcmp(tipo,'ENCOM'))       % Pretend that its a GMT grid
    ID = fread(fid,180,'*char');        % We don't use this header info, so strip it
    no_val = fread(fid,1,'float32');
    ID = fread(fid,4,'*char');      n_rows = fread(fid,1,'float32');    % ROWS FLAG
    ID = fread(fid,4,'*char');      n_cols = fread(fid,1,'float32');    % COLS FLAG
    ID = fread(fid,4,'*char');      x_min = fread(fid,1,'float32');     % XORIG FLAG
    ID = fread(fid,4,'*char');      y_min = fread(fid,1,'float32');     % YORIG FLAG
    ID = fread(fid,4,'*char');      dx = fread(fid,1,'float32');        % DX FLAG
    ID = fread(fid,4,'*char');      dy = fread(fid,1,'float32');        % DY FLAG
    ID = fread(fid,4,'*char');      rot = fread(fid,1,'float32');       % DEGR FLAG (I'll use it one day)
    Z = single(fread(fid,n_rows*n_cols,'float32'));    fclose(fid);
    Z = reshape(Z, n_cols, n_rows)';
    Z(Z == no_val) = NaN;
    [zzz] = grdutils(Z,'-L+');  z_min = zzz(1);     z_max = zzz(2);     handles.have_nans = zzz(3); clear zzz;
    x_max = x_min + (n_cols-1) * dx;        y_max = y_min + (n_rows-1) * dy;
    X = linspace(x_min,x_max,n_cols);       Y = linspace(y_min,y_max,n_rows);
    head = [x_min x_max y_min y_max z_min z_max 0 dx dy];
    handles.image_type = 1;     handles.computed_grid = 1;    handles.grdname = [];
elseif (strcmp(tipo,'MAN_ASCII'))
    h1 = fgetl(fid);    h2 = fgetl(fid);    h3 = fgetl(fid);    h4 = fgetl(fid);    h5 = fgetl(fid);
    n_rows = str2double(h1(6:10));          n_cols = str2double(h1(16:20));
    y_inc = str2double(h2(6:10));           x_inc = str2double(h2(16:20));
    no_val = str2double(h2(25:31));         azim = str2double(h2(35:40));
    x_min = str2double(h2(46:60));          y_max = str2double(h2(66:80));
    Z = single(fscanf(fid,'%f',inf));       fclose(fid);
    Z = flipud(reshape(Z,n_rows,n_cols));
    Z(Z == no_val) = NaN;
    x_max = x_min + (n_cols-1) * x_inc;     y_min = y_max - (n_rows-1) * y_inc;
    if (azim ~= 0)
        Z = transform_fun('imrotate',Z,azim,'bilinear','loose');
        n_cols = size(Z,2);      n_rows = size(Z,1);
        azim_rad = azim * pi / 180;
        rot = [cos(azim_rad) sin(azim_rad); ...
                -sin(azim_rad) cos(azim_rad)];
        % Compute the des-rotated grid limits
        UL = rot * [x_min; y_max];                      % Upper Left corner
        UR = rot * [x_max; y_max];                      % Upper Right corner
        LR = rot * [x_max; y_min];                      % Lower Right  corner
        LL = rot * [x_min; y_min];                      % Lower Left  corner
        x_min = min([UL(1) UR(1) LR(1) LL(1)]);      x_max = max([UL(1) UR(1) LR(1) LL(1)]);
        y_min = min([UL(2) UR(2) LR(2) LL(2)]);      y_max = max([UL(2) UR(2) LR(2) LL(2)]);
        x_inc = (x_max - x_min) / (n_cols - 1);         % We need to recompute those
        y_inc = (y_max - y_min) / (n_rows - 1);
    end
    [zzz] = grdutils(Z,'-L+');  z_min = zzz(1);     z_max = zzz(2);     handles.have_nans = zzz(3); clear zzz;
    X = linspace(x_min,x_max,n_cols);       Y = linspace(y_min,y_max,n_rows);
    head = [x_min x_max y_min y_max z_min z_max 0 x_inc y_inc];
    handles.image_type = 1;     handles.computed_grid = 1;    handles.grdname = [];
end
