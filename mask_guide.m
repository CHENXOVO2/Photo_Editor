
function varargout = mask_guide(varargin)
% MASK_GUIDE MATLAB code for mask_guide.fig
%      MASK_GUIDE, by itself, creates a new MASK_GUIDE or raises the existing
%      singleton*.
%
%      H = MASK_GUIDE returns the handle to a new MASK_GUIDE or the handle to
%      the existing singleton*.
%
%      MASK_GUIDE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MASK_GUIDE.M with the given input arguments.
%
%      MASK_GUIDE('Property','Value',...) creates a new MASK_GUIDE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before mask_guide_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to mask_guide_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help mask_guide

% Last Modified by GUIDE v2.5 23-Apr-2026 12:00:22

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @mask_guide_OpeningFcn, ...
                   'gui_OutputFcn',  @mask_guide_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before mask_guide is made visible.
function mask_guide_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to mask_guide (see VARARGIN)

% Choose default command line output for mask_guide
handles.output = hObject;

% --- 初始化变量 ---
handles.originalImage = [];
handles.grayImage = [];
handles.mask_add = [];   % 用户手绘的前景
handles.mask_sub = [];   % 用户手绘的背景（擦除）
handles.finalMask = [];  % 最终生成的mask

% --- 设置默认参数 ---
% 假设控件创建顺序是：从左到右，从上到下
% edit1: canny低阈值
% edit2: 膨胀半径 (第一行右侧) -> 如果不对请改为 edit3
% edit3: canny高阈值 (第二行左侧) -> 如果不对请改为 edit2
% edit4: 最小区域面积 (第二行右侧)
set(handles.edit1, 'String', '0.1'); 
set(handles.edit3, 'String', '0.4'); 
set(handles.edit2, 'String', '2');   
set(handles.edit4, 'String', '50');  

% 确保下拉菜单默认选中第一项（前景）
set(handles.popupmenu1, 'Value', 1);

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes mask_guide wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = mask_guide_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- 按钮 1: 载入图像 ---
function pushbutton1_Callback(hObject, eventdata, handles)
[filename, pathname] = uigetfile({'*.jpg;*.png;*.bmp', 'Image Files'}, 'Select an image');
if isequal(filename, 0), return; end

fullpath = fullfile(pathname, filename);
img = imread(fullpath);

handles.originalImage = img;
if size(img, 3) == 3
    handles.grayImage = rgb2gray(img);
else
    handles.grayImage = img;
end

% 初始化 Mask 矩阵
sz = size(handles.grayImage);
handles.mask_add = false(sz(1), sz(2));
handles.mask_sub = false(sz(1), sz(2));

% 显示原图
axes(handles.axes1);
imshow(img);
title('Original Image');

% 清空 Mask 显示区
axes(handles.axes2);
cla;

guidata(hObject, handles);


% --- 按钮 2: 绘制 (手绘前景/背景) ---
function pushbutton2_Callback(hObject, eventdata, handles)
if isempty(handles.originalImage)
    errordlg('请先载入图像！', 'Error');
    return;
end

% 1. 强制聚焦到 axes1
axes(handles.axes1);

% 2. 提示
h_msg = msgbox('请在图像上绘制闭合区域，完成后【双击】结束。', '提示', 'modal');
drawnow;

try
    % 3. 创建手绘对象
    h = imfreehand(handles.axes1);
    
    % 4. 等待用户完成绘制
    wait(h);
    
    % 5. 创建二值掩膜
    roi_mask = createMask(h);
    
    % 6. 删除手绘对象
    delete(h);
    
    % 关闭提示框
    delete(h_msg);
    
catch ME
    % 如果出错，关闭提示框并报错
    delete(h_msg);
    errordlg(['绘制失败: ' ME.message], 'Error');
    return;
end

% 7. 获取下拉菜单选择 (前景/背景)
val = get(handles.popupmenu1, 'Value');
str = get(handles.popupmenu1, 'String');
selected_mode = str{val};

% 8. 逻辑判断：互斥处理
if strcmp(selected_mode, '前景') 
    handles.mask_add = handles.mask_add | roi_mask; % 添加到前景
    handles.mask_sub = handles.mask_sub & ~roi_mask; % 从背景中移除
else
    handles.mask_sub = handles.mask_sub | roi_mask; % 添加到背景（擦除）
    handles.mask_add = handles.mask_add & ~roi_mask; % 从前景中移除
end

% 9. 刷新 axes1 显示，给用户反馈
axes(handles.axes1);
imshow(handles.originalImage);
n_add = sum(handles.mask_add(:));
n_sub = sum(handles.mask_sub(:));
title(sprintf('Original (Add: %d px, Sub: %d px)', n_add, n_sub));

guidata(hObject, handles);


% --- 按钮 3: 平移 ---
function pushbutton3_Callback(hObject, eventdata, handles)
pan on;
msgbox('平移模式已开启，请在图像上拖动鼠标。', '提示');


% --- 按钮 4: 缩放 ---
function pushbutton4_Callback(hObject, eventdata, handles)
zoom on;
msgbox('缩放模式已开启，请滚动鼠标滚轮。', '提示');


% --- 按钮 5: 删除选中 ---
function pushbutton5_Callback(hObject, eventdata, handles)
% 简单实现：删除当前 axes 上的选中图形对象
try
    delete(get(gca, 'Selected'));
catch
end


% --- 按钮 6: 预览 (核心算法) ---
function pushbutton6_Callback(hObject, eventdata, handles)
if isempty(handles.grayImage)
    errordlg('请先载入图像！', 'Error');
    return;
end

% --- 获取参数 ---
low = str2double(get(handles.edit1, 'String'));
high = str2double(get(handles.edit3, 'String'));
radius = str2double(get(handles.edit2, 'String'));
min_area = str2double(get(handles.edit4, 'String'));

% 获取复选框状态
is_sharpen = get(handles.checkbox2, 'Value'); % 锐化
is_fill = get(handles.checkbox3, 'Value');    % 填充空白
is_close = get(handles.checkbox4, 'Value');   % 边缘闭合

% 1. 预处理
I = handles.grayImage;
if is_sharpen
    I = imsharpen(I);
end

% 2. Canny 边缘检测
if low > high
    temp = low; low = high; high = temp; % 确保 low < high
end
if low <= 0
    low = 0.01;
end
bw = edge(I, 'Canny', [low, high]);

% 3. 形态学处理
se = strel('disk', radius);
if is_close
    bw = imclose(bw, se);
end
if radius > 0
    bw = imdilate(bw, se);
end
if is_fill
    bw = imfill(bw, 'holes');
end

% 4. 面积过滤 (去除噪点)
if min_area > 0
    bw = bwareaopen(bw, min_area);
end

% 5. 合并手动绘制区域
% 逻辑：(自动边缘 OR 手动前景) AND (NOT 手动背景)
final_mask = (bw | handles.mask_add) & (~handles.mask_sub);
handles.finalMask = final_mask;

% 6. 显示结果
axes(handles.axes2);
imshow(final_mask);
title('Final Mask');

guidata(hObject, handles);


% --- 按钮 7: 清空 ---
function pushbutton7_Callback(hObject, eventdata, handles)
if ~isempty(handles.originalImage)
    % 重置 Mask 数据
    sz = size(handles.grayImage);
    handles.mask_add = false(sz(1), sz(2));
    handles.mask_sub = false(sz(1), sz(2));
    handles.finalMask = [];
    
    % 刷新显示
    axes(handles.axes1);
    imshow(handles.originalImage);
    title('Original Image');
    
    axes(handles.axes2);
    cla;
    
    guidata(hObject, handles);
end


% --- 按钮 8: 保存 ---
function pushbutton8_Callback(hObject, eventdata, handles)
if isempty(handles.finalMask)
    msgbox('请先点击“预览”生成Mask', '提示');
    return;
end

[filename, pathname] = uiputfile({'*.png', 'Mask Files'}, 'Save Mask');
if isequal(filename, 0), return; end

imwrite(handles.finalMask, fullfile(pathname, filename));
msgbox('保存成功！', 'Success');


% --- Executes on button press in pushbutton10.
function pushbutton10_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- 按钮: 格式化为0/1矩阵 ---

if isempty(handles.finalMask)
    errordlg('请先点击“预览”生成Mask！', 'Error');
    return;
end

% 转为 double 类型 (0/1)
figure;
uitable('Data', double(handles.finalMask));
guidata(hObject, handles);
