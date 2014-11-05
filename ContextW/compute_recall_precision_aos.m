function compute_recall_precision_aos

cls = 'car';

% evaluation parameter
MIN_HEIGHT = [40, 25, 25];     % minimum height for evaluated groundtruth/detections
MAX_OCCLUSION = [0, 1, 2];     % maximum occlusion level of the groundtruth used for evaluation
MAX_TRUNCATION = [0.15, 0.3, 0.5]; % maximum truncation level of the groundtruth used for evaluation
MIN_OVERLAP = 0.7;
N_SAMPLE_PTS = 41;

% KITTI path
exemplar_globals;
root_dir = KITTIroot;
data_set = 'training';
cam = 2;
label_dir = fullfile(root_dir, [data_set '/label_' num2str(cam)]);

% read ids of validation images
object = load('kitti_ids_new.mat');
ids = object.ids_val;
M = numel(ids);

% read ground truth
groundtruths = cell(1, M);
for i = 1:M
    % read ground truth 
    img_idx = ids(i);
    groundtruths{i} = readLabels(label_dir, img_idx);
end
fprintf('load ground truth done\n');

% read detection results
% result_dir = 'kitti_train_ap_125';
% filename = sprintf('%s/odets.mat', result_dir);
% object = load(filename);
% detections = object.odets;
detections = cell(1, M);
for i = 1:M
    % read ground truth 
    img_idx = ids(i);
    filename = sprintf('results_kitti_train/%06d.txt', img_idx);
    fid = fopen(filename, 'r');
    C = textscan(fid, '%s %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f');
    fclose(fid);
    det = [C{5} C{6} C{7} C{8} C{2} C{16}];
    detections{i} = det;
end
fprintf('load detection done\n');

for difficulty = 1:3
    % for each image
    scores_all = [];
    n_gt_all = 0;
    ignored_gt_all = cell(1, M);
    dontcare_gt_all = cell(1, M);
    for i = 1:M
        gt = groundtruths{i};
        num = numel(gt);
        % clean data
        % extract ground truth bounding boxes for current evaluation class
        ignored_gt = zeros(1, num);
        n_gt = 0;
        dontcare_gt = zeros(1, num);
        n_dc = 0;
        for j = 1:num
            if strcmpi(cls, gt(j).type) == 1
                valid_class = 1;
            elseif strcmpi('van', gt(j).type) == 1
                valid_class = 0;
            else
                valid_class = -1;
            end
            
            height = gt(j).y2 - gt(j).y1;    
            if(gt(j).occlusion > MAX_OCCLUSION(difficulty) || ...
                gt(j).truncation > MAX_TRUNCATION(difficulty) || ...
                height < MIN_HEIGHT(difficulty))
                ignore = true;            
            else
                ignore = false;
            end
            
            if valid_class == 1 && ignore == false
                ignored_gt(j) = 0;
                n_gt = n_gt + 1;
            elseif valid_class == 0 || (valid_class == 1 && ignore == true) 
                ignored_gt(j) = 1;
            else
                ignored_gt(j) = -1;
            end
            
            if strcmp('DontCare', gt(j).type) == 1
                dontcare_gt(j) = 1;
                n_dc = n_dc + 1;
            end
        end
        
        % compute statistics
        det = detections{i};
%         det = truncate_detections(det);
        
        num_det = size(det, 1);
        assigned_detection = zeros(1, num_det);
        scores = [];
        count = 0;
        for j = 1:num
            if ignored_gt(j) == -1
                continue;
            end
            
            box_gt = [gt(j).x1 gt(j).y1 gt(j).x2 gt(j).y2];
            valid_detection = -inf;
            % find the maximum score for the candidates and get idx of respective detection
            for k = 1:num_det
                if assigned_detection(k) == 1
                    continue;
                end
                overlap = boxoverlap(det(k,:), box_gt);
                if overlap > MIN_OVERLAP && det(k,6) > valid_detection
                    det_idx = k;
                    valid_detection = det(k,6);
                end
            end
            
            if isinf(valid_detection) == 0 && ignored_gt(j) == 1
                assigned_detection(det_idx) = 1;
            elseif isinf(valid_detection) == 0
                assigned_detection(det_idx) = 1;
                count = count + 1;
                scores(count) = det(det_idx, 6);
            end
        end
        scores_all = [scores_all scores];
        n_gt_all = n_gt_all + n_gt;
        ignored_gt_all{i} = ignored_gt;
        dontcare_gt_all{i} = dontcare_gt;
    end
    % get thresholds
    thresholds = get_thresholds(scores_all, n_gt_all, N_SAMPLE_PTS);
    
    nt = numel(thresholds);
    tp = zeros(nt, 1);
    fp = zeros(nt, 1);
    fn = zeros(nt, 1);
    recall = zeros(nt, 1);
    precision = zeros(nt, 1);
    
    % for each image
    for i = 1:M
        gt = groundtruths{i};
        num = numel(gt);
        ignored_gt = ignored_gt_all{i};
        
        det = detections{i};
%         det = truncate_detections(det);    
        num_det = size(det, 1);
        
        % for each threshold
        for t = 1:nt
            % compute statistics
            assigned_detection = zeros(1, num_det);
            % for each ground truth
            for j = 1:num
                if ignored_gt(j) == -1
                    continue;
                end

                box_gt = [gt(j).x1 gt(j).y1 gt(j).x2 gt(j).y2];
                valid_detection = -inf;
                max_overlap = 0;
                % for computing pr curve values, the candidate with the greatest overlap is considered
                for k = 1:num_det
                    if assigned_detection(k) == 1
                        continue;
                    end
                    if det(k,6) < thresholds(t)
                        continue;
                    end
                    overlap = boxoverlap(det(k,:), box_gt);
                    if overlap > MIN_OVERLAP && overlap > max_overlap
                        max_overlap = overlap;
                        det_idx = k;
                        valid_detection = 1;
                    end
                end

                if isinf(valid_detection) == 1 && ignored_gt(j) == 0
                    fn(t) = fn(t) + 1;
                elseif isinf(valid_detection) == 0 && ignored_gt(j) == 1
                    assigned_detection(det_idx) = 1;
                elseif isinf(valid_detection) == 0
                    tp(t) = tp(t) + 1;
                    assigned_detection(det_idx) = 1;
                end
            end
            
            % compute false positive
            for k = 1:num_det
                if assigned_detection(k) == 0 && det(k,6) >= thresholds(t)
                    fp(t) = fp(t) + 1;
                end
            end
            
            % do not consider detections overlapping with stuff area
            dontcare_gt = dontcare_gt_all{i};
            nstuff = 0;
            for j = 1:num
                if dontcare_gt(j) == 0
                    continue;
                end

                box_gt = [gt(j).x1 gt(j).y1 gt(j).x2 gt(j).y2];
                for k = 1:num_det
                    if assigned_detection(k) == 1
                        continue;
                    end
                    if det(k,6) < thresholds(t)
                        continue;
                    end
                    overlap = boxoverlap(det(k,:), box_gt);
                    if overlap > MIN_OVERLAP
                        assigned_detection(k) = 1;
                        nstuff = nstuff + 1;
                    end
                end
            end
            
            fp(t) = fp(t) - nstuff;
        end
    end
    
    for t = 1:nt
        % compute recall and precision
        recall(t) = tp(t) / (tp(t) + fn(t));
        precision(t) = tp(t) / (tp(t) + fp(t));
    end
    
    ap = VOCap(recall, precision);
    disp(ap);
end


function thresholds = get_thresholds(v, n_groundtruth, N_SAMPLE_PTS)

% sort scores in descending order
v = sort(v, 'descend');

% get scores for linearly spaced recall
current_recall = 0;
num = numel(v);
thresholds = [];
count = 0;
for i = 1:num

    % check if right-hand-side recall with respect to current recall is close than left-hand-side one
    % in this case, skip the current detection score
    l_recall = i / n_groundtruth;
    if i < num
      r_recall = (i+1) / n_groundtruth;
    else
      r_recall = l_recall;
    end

    if (r_recall - current_recall) < (current_recall - l_recall) && i < num
      continue;
    end

    % left recall is the best approximation, so use this and goto next recall step for approximation
    recall = l_recall;

    % the next recall step was reached
    count = count + 1;
    thresholds(count) = v(i);
    current_recall = current_recall + 1.0/(N_SAMPLE_PTS-1.0);
end


function det_new = truncate_detections(det)

if isempty(det) == 0
    imsize = [1224, 370]; % kittisize
    det(det(:, 1) < 0, 1) = 0;
    det(det(:, 2) < 0, 2) = 0;
    det(det(:, 1) > imsize(1), 1) = imsize(1);
    det(det(:, 2) > imsize(2), 2) = imsize(2);
    det(det(:, 3) < 0, 1) = 0;
    det(det(:, 4) < 0, 2) = 0;
    det(det(:, 3) > imsize(1), 3) = imsize(1);
    det(det(:, 4) > imsize(2), 4) = imsize(2);
end
det_new = det;