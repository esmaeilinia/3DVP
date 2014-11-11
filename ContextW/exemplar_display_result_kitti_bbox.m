function exemplar_display_result_kitti_bbox

threshold = -2;
is_save = 0;
is_train = 0;

if is_train
    result_dir = 'kitti_train_ap_125';
else
    result_dir = 'kitti_test_ap_227';
end

% read detection results
filename = sprintf('%s/odets_3d.mat', result_dir);
object = load(filename);
dets = object.dets_3d;
fprintf('load detection done\n');

% read ids of validation images
object = load('kitti_ids_new.mat');
if is_train
    ids = object.ids_val;
else
    ids = object.ids_test;
end
N = numel(ids);

% KITTI path
exemplar_globals;
root_dir = KITTIroot;
if is_train
    data_set = 'training';
else
    data_set = 'testing';
end
cam = 2;
image_dir = fullfile(root_dir, [data_set '/image_' num2str(cam)]);
label_dir = fullfile(root_dir, [data_set '/label_' num2str(cam)]);

figure;
cmap = colormap(summer);
for i = 1:N
    img_idx = ids(i);
    disp(img_idx);
    
    % read ground truth bounding box
    if is_train
        objects = readLabels(label_dir, img_idx);
        clsinds = strmatch(cls, lower({objects(:).type}), 'exact');
        n = numel(clsinds);
        bbox_gt = zeros(n, 4); 
        for j = 1:n
            bbox_gt(j,:) = [objects(clsinds(j)).x1 objects(clsinds(j)).y1 ...
                objects(clsinds(j)).x2 objects(clsinds(j)).y2];     
        end
        flags_gt = zeros(n, 1);
    end
    
    % get predicted bounding box
    objects = dets{i};
    num = numel(objects);    
    det = zeros(num, 6);    
    for k = 1:num
        det(k,:) = [objects(k).x1 objects(k).y1 objects(k).x2 objects(k).y2 ...
                objects(k).cid objects(k).score];            
    end    
    
    if isempty(det) == 1
        fprintf('no detection for image %d\n', img_idx);
        continue;
    end
    if max(det(:,6)) < threshold
        fprintf('maximum score %.2f is smaller than threshold\n', max(det(:,6)));
        continue;
    end
    if isempty(det) == 0
        I = det(:,6) >= threshold;
        det = det(I,:);
        height = det(:,4) - det(:,2);
        [~, I] = sort(height);
        det = det(I,:);
    end
    num = size(det, 1);
    
    % for each predicted bounding box
    if is_train
        flags_pr = zeros(num, 1);
        for j = 1:num
            bbox_pr = det(j, 1:4);  

            % compute box overlap
            if isempty(bbox_gt) == 0
                o = boxoverlap(bbox_gt, bbox_pr);
                [maxo, index] = max(o);
                if maxo >= 0.7 && flags_gt(index) == 0
                    flags_pr(j) = 1;
                    flags_gt(index) = 1;
                end
            end
        end
    end
    
    file_img = sprintf('%s/%06d.png', image_dir, img_idx);
    I = imread(file_img);
    
    % show all the detections
%     figure(1);
%     imshow(I);
%     hold on;
%     
%     for k = 1:size(dets{i},1)
%         bbox_pr = dets{i}(k,1:4);
%         bbox_draw = [bbox_pr(1), bbox_pr(2), bbox_pr(3)-bbox_pr(1), bbox_pr(4)-bbox_pr(2)];
%         rectangle('Position', bbox_draw, 'EdgeColor', 'g', 'LineWidth', 2);
%     end
%     hold off;
    
    imshow(I);
    hold on;
    for k = 1:num
        if det(k,6) > threshold
            % get predicted bounding box
            bbox_pr = det(k,1:4);
            bbox_draw = [bbox_pr(1), bbox_pr(2), bbox_pr(3)-bbox_pr(1), bbox_pr(4)-bbox_pr(2)];
            if is_train
                if flags_pr(k)
                    rectangle('Position', bbox_draw, 'EdgeColor', 'g', 'LineWidth', 2);
                else
                    rectangle('Position', bbox_draw, 'EdgeColor', 'r', 'LineWidth', 2);
                end
            else
                index_color = 1 + floor((k-1) * size(cmap,1) / num);
                rectangle('Position', bbox_draw, 'EdgeColor', cmap(index_color,:), 'LineWidth', 4);
            end
%             s = sprintf('%.2f', det(k,6));
%             text(bbox_pr(1), bbox_pr(2), s, 'FontSize', 4, 'BackgroundColor', 'c');
        end
    end
    
    if is_train
        for k = 1:n
            if flags_gt(k) == 0
                bbox = bbox_gt(k,1:4);
                bbox_draw = [bbox(1), bbox(2), bbox(3)-bbox(1), bbox(4)-bbox(2)];
                rectangle('Position', bbox_draw, 'EdgeColor', 'y', 'LineWidth', 2);
            end
        end
    end
    hold off;
    
    if is_save
        filename = fullfile('result_images', sprintf('%06d.png', img_idx));
        saveas(hf, filename);
    else
        pause;
    end
end  