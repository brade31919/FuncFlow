function [refined_mask, IOUs] = refine_consistentfunc_with_gop(input_mask, img)
%% ===============================
%% Refines a heatmap into a binary mask using Geodesic Object Proposals.
% For details, please refer to section 6 of the attached pdf and
% <http://vladlen.info/publications/geodesic-object-proposals/>
%=================================
%% INPUT:
% input_mask - (H x W double) the input heatmap to match a binary mask to
% img - (H x W x 3 double) the original rgb image
%=================================
%% OUTPUT:
% refined_mask - (H x W double) the final output mask generated by 'GOP'
%% ===============================
%% Initialize the GOP pipeline
init_gop;
gop_mex( 'setDetector', 'MultiScaleStructuredForest("/home/zimo/Documents/dense_functional_map_matching/external/gop_1.3/data/sf.dat")' );

p = Proposal('max_iou', 1.0,...
    'unary', 4, 2, 'seedUnary()', 'backgroundUnary({0,15})',...
    'unary', 0, 4, 'zeroUnary()', 'backgroundUnary({0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15})' ...
    );

os = OverSegmentation( img );
props = p.propose( os );
IOUs_seg = zeros(1, size(props,1));
% ================================
%% Compute the relaxed IOU score for each proposal
mean_input = mean(input_mask(input_mask~=0));
for i=1:size(props,1)
    mask = props(i,:);
    m = double(uint8(mask( os.s()+1 )));
    intersection_seg = sum(sum(m .* input_mask))^2 / sum(sum(logical(m .* input_mask)));
    %intersection_seg = sum(sum(m .* input_mask))^2;
    
    inverse_input_mask = input_mask;
    %inverse_input_mask(inverse_input_mask ~= 0) = 1 - inverse_input_mask(inverse_input_mask~=0);
    union_seg = sum(sum(logical(m + inverse_input_mask)));
    IOUs_seg(i) = intersection_seg/union_seg;
end
IOUs = IOUs_seg;
IOUs(isnan(IOUs)) = 0;

%=================================================
%% Find the top k proposals given their RIOU scores
k =1;
[~, ids] = sort(IOUs);
top_k = ids(end-k + 1:end);
top_props = cell(k,1);
for z = 1:k
    new_prop = props(top_k(z),:);
    new_mask = double(uint8(new_prop(os.s() + 1)));
    top_props{z} = reshape(new_mask, 1, []);
end

top_props = cell2mat(top_props);
total_intersection = prod(top_props,1);
%=================================================
%% Pick proposal which corresponds with the intersection of the top k proposals
top_IOUs = zeros(1,k);
for r = 1:k
    intersection = sum(top_props(r,:).*total_intersection);
    union = sum(logical(top_props(r,:) + total_intersection));
    top_IOUs(r) = intersection/union;
end

[~, bestid] = max(top_IOUs);
refined_mask = reshape(top_props(bestid,:), size(img,1), size(img,2));
%====================================================
%% Code for debugging with figures
%====================================================
%refined_mask = intersect_mask;

% [~, maxid] = max(IOUs);
% final_mask = props(maxid,:);
% refined_mask = double(uint8(final_mask(os.s()+1)));
%figure; imagesc(refined_mask); input(' ');



% figure;
% subplot(1,11,1); imshow(img);
% for t=1:10
%     next = props(ids(end - t + 1),:);
%     examp = double(uint8(next(os.s()+1)));
%     subplot(1,11,t+1); imshow(examp);
% end
% input(' ' );
%=====================================================
end