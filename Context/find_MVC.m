function [I, X_wo, margin] = find_MVC(W_s, W_a, centers, Tdata)

% load groundtruth feature
Feat_true = Tdata.Feat_true;

% load detections
Detections = Tdata.Detections;
Scores = Tdata.Scores;
Matching = Tdata.Matching;
Overlaps = Tdata.Overlaps;
Matching(Overlaps < 0.1) = 1;

% load loss
loss = Tdata.loss;
num = size(Detections, 1);

% Initial energy is just the weighted local scores 
E = zeros(num, 1);
for i = 1:numel(centers)
    index = find(Detections(:, 5) == centers(i));
    if isempty(index) == 0
        E(index) = W_a(2*i - 1) .* Scores(index) + W_a(2*i);
    end
end

Pos = E + loss(:, 1);
Neg = loss(:, 2);

[I, S] = maximize(Detections, Matching, Pos, Neg, W_s);
inds = find(I == 1);
[PSI_wo, PHI_wo] = compute_feature(Detections(inds,:), Scores(inds), Matching(inds, inds), centers);
Feature_wo = [PSI_wo; PHI_wo];

X_wo = Feat_true -  Feature_wo;
bg = I == 0;
fg = I == 1;
margin = sum(loss(fg,1)) + sum(loss(bg, 2));
% mvc_score = [W_s; W_a]'*[PSI_wo_mex; PHI_wo_mex] + margin;