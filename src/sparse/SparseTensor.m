classdef (InferiorClasses = {?Tensor, ?MpsTensor}) SparseTensor < AbstractTensor
    % Class for multi-dimensional sparse objects.
    
    properties (Access = private)
        ind = []
        sz = []
        var (:, 1) Tensor = Tensor.empty(0, 1);
    end
    
    methods
        function t = SparseTensor(varargin)
            if nargin == 0 || (nargin == 1 && isempty(varargin{1}))
                return;
                
            elseif nargin == 1  % cast from existing object
                source = varargin{1};
                
                if isa(source, 'SparseTensor')
                    t.ind = source.ind;
                    t.sz = source.sz;
                    t.var = source.var;
                    
                elseif isa(source, 'Tensor')
                    t.sz = ones(1, nspaces(source(1)));
                    t.sz(1:ndims(source)) = size(source);
                    
                    t.ind = ind2sub_(t.sz, 1:numel(source));
                    t.var = source(:);
                    
                else
                    error('sparse:ArgError', 'Unknown syntax.');
                end
                
            elseif nargin == 2  % indices and values
                ind = varargin{1};
                var = reshape(varargin{2}, [], 1);
                if isscalar(var), var = repmat(var, size(ind, 1), 1); end
                assert(size(ind, 1) == size(var, 1), 'sparse:argerror', ...
                    'indices and values must be the same size.');
                t.ind = ind;
                t.var = var;
                t.sz = max(ind, [], 1);
                
            elseif nargin == 3  % indices, values and size
                ind = varargin{1};
                if ~isempty(ind) && ~isempty(varargin{2})
                    var = reshape(varargin{2}, [], 1);
                    if isscalar(var), var = repmat(var, size(ind, 1), 1); end
                    assert(size(ind, 1) == size(var, 1), 'sparse:argerror', ...
                        'indices and values must be the same size.');
                    sz = reshape(varargin{3}, 1, []);
                    assert(isempty(ind) || size(ind, 2) == length(sz), 'sparse:argerror', ...
                        'number of indices does not match size vector.');
                    assert(isempty(ind) || all(max(ind, [], 1) <= sz), 'sparse:argerror', ...
                        'indices must not exceed size vector.');
                    t.var = var;
                else
                    sz = reshape(varargin{3}, 1, []);
                end
                t.ind = ind;
                t.sz = sz;
                
            else
                error('sparse:argerror', 'unknown syntax.');
            end
        end
        
        function t = permute(t, p)
            if ~isempty(t.ind)
                t.ind = t.ind(:, p);
            end
            t.sz = t.sz(p);
        end
        
        function t = reshape(t, sz)
            assert(prod(sz) == prod(t.sz), ...
                'sparse:argerror', 'To reshape the number of elements must not change.');
            idx = sub2ind_(t.sz, t.ind);
            t.ind = ind2sub_(sz, idx);
            t.sz  = sz;
        end
        
        function B = full(A)
            inds = ind2sub_(A.sz, 1:prod(A.sz));
            
            [lia, locb] = ismember(inds, A.ind, 'rows');
            B(lia) = A.var(locb(lia));
            
            if ~all(lia)
                s = arrayfun(@(i) space(A, i), 1:ndims(A), 'UniformOutput', false);
                r = rank(A.var(1));
                for i = find(~lia).'
                    allspace = arrayfun(@(j) s{j}(inds(i, j)), 1:length(s));
                    B(i) = Tensor.zeros(allspace(1:r(1)), allspace(r(1)+1:end)');
                end
            end
            B = reshape(B, A.sz);
        end
        
        function s = space(t, i)
            assert(isscalar(i), 'sparse:argerror', ...
                'Can only obtain spaces for single index.');
            for j = size(t, i):-1:1
                el = t.var(find(t.ind(:, i), 1));
                if isempty(el)
                    warning('cannot deduce space.');
                    continue;
                end
                s(j) = space(t.var(find(t.ind(:, i) == j, 1)), i);
            end
        end
        
        function n = nspaces(A)
            if nnz(A) == 0
                n = ndims(A);
            else
                n = nspaces(A.var(1));
            end
        end
        
        function n = ndims(A)
            n = length(A.sz);
        end
        
        function r = rank(A)
            if nnz(A) == 0
                r = [ndims(A) 0];
            else
                r = rank(A.var(1));
            end
        end
        
        function sz = size(a, i)
            if nargin == 1
                sz = a.sz;
                return
            end
            
            sz = ones(1, max(i));
            sz(1:length(a.sz)) = a.sz;
            sz = sz(i);
        end
        
        function disp(t)
            nz = nnz(t);
            if nz == 0
                fprintf('all-zero %s of size %s\n', class(t), ...
                    regexprep(mat2str(t.sz), {'\[', '\]', '\s+'}, {'', '', 'x'}));
                return
            end
            
            fprintf('%s of size %s with %d nonzeros:\n', class(t), ...
                regexprep(mat2str(t.sz), {'\[', '\]', '\s+'}, {'', '', 'x'}), nz);
            
            spc = floor(log10(max(double(t.ind), [], 1))) + 1;
            if numel(spc) == 1
                fmt = strcat("\t(%", num2str(spc(1)), "u)");
            else
                fmt = strcat("\t(%", num2str(spc(1)), "u,");
                for i = 2:numel(spc) - 1
                    fmt = strcat(fmt, "%", num2str(spc(i)), "u,");
                end
                fmt = strcat(fmt, "%", num2str(spc(end)), "u)");
            end
            
            for i = 1:nz
                fprintf('%s\t\t', compose(fmt, t.ind(i,:)));
                disp(t.var(i));
                fprintf('\n');
            end
        end
        
        function type = underlyingType(a)
            if isempty(a.var)
                type = 'double';
            else
                type = underlyingType(a.var);
            end
        end
        
        function bool = issparse(~)
            bool = true;
        end
        
        function bool = isscalar(t)
            bool = prod(t.sz) == 1;
        end
        
        function n = nnz(t)
            n = length(t.var);
        end
        
        function bools = eq(a, b)
            arguments
                a SparseTensor
                b SparseTensor
            end
            
            if isscalar(a) && isscalar(b)
                bools = (isempty(a.var) && isempty(b.var)) || ...
                    (~isempty(a.var) && ~isempty(b.var) && a.var == b.var);
                return
            end
            
            if isscalar(a)
                if nnz(a) == 0
                    bools = true(size(b));
                    if nnz(b) ~= 0
                        bools(sub2ind_(b.sz, b.ind)) = false;
                    end
                else
                    bools = false(size(b));
                    bools(sub2ind_(b.sz, b.ind)) = a.var == b.var;
                end
                return
            end
            
            if isscalar(b)
                bools = b == a;
                return
            end
            
            assert(isequal(size(a), size(b)), 'sparse:dimerror', ...
                'input sizes incompatible');
            bools = true(size(a.inds));
            [inds, ia, ib] = intersect(a.ind, b.ind, 'rows');
            
            bools(sub2ind_(a.sz, a.ind)) = false;
            bools(sub2ind_(b.sz, b.ind)) = false;
            bools(sub2ind_(a.sz, inds)) = a.var(ia) == b.var(ib);
        end
    end
    
    %% Linear Algebra
    methods
        function a = conj(a)
            if ~isempty(a.var)
                a.var = conj(a.var);
            end
        end
        
        function d = dot(a, b)
            [~, ia, ib] = intersect(a.ind, b.ind, 'rows');
            if isempty(ia), d = 0; return; end
            d = dot(a.var(ia), b.var(ib));
        end
            
        function a = minus(a, b)
            a = a + (-b);
        end
        
        function c = mtimes(a, b)
            szA = a.sz;
            szB = b.sz;
            assert(length(szA) == 2 && length(szB) == 2, 'sparse:argerror', ...
                'mtimes only defined for matrices.');
            assert(szA(2) == szB(1), 'sparse:dimerror', ...
                'incompatible sizes for mtimes.');
            
            cvar = [];
            cind = double.empty(0, 2);
            
            for k = 1:size(a, 2)
                rowlinds = a.ind(:, 2) == k;
                if ~any(rowlinds), continue; end
                
                collinds = b.ind(:, 1) == k;
                if ~any(collinds), continue; end
                
                rowinds = find(rowlinds);
                colinds = find(collinds);
                
                for i = rowinds.'
                    av = a.var(i);
                    ai = a.ind(i, 1);
                    for j = colinds.'
                        bv = b.var(j);
                        bj = b.ind(j, 2);
                        
                        
                        mask = all([ai bj] == cind, 2);
                        if any(mask)
                            cvar(mask) = cvar(mask) + av * bv;
                        else
                            cvar(end+1) = av * bv;
                            cind = [cind; ai bj];
                        end
                    end
                end
            end
            c = SparseTensor(cind, cvar, [szA(1) szB(2)]);
        end
        
        function n = norm(t, p)
            arguments
                t
                p = 'fro'
            end
            
            if isempty(t.var), n = 0; return; end
            n = norm(t.var);
        end
        
        function t = normalize(t)
            if isempty(t.var)
                warning('sparse:empty', 'cannot normalize an empty tensor.');
            end
            t = t .* (1 / norm(t));
        end
        
        function a = plus(a, b)
            n = max(ndims(a), ndims(b));
            assert(isequal(size(a, 1:n), size(b, 1:n)), ...
                'sparse:dimerror', 'input dimensions incompatible.');
            
            if ~issparse(a)
                if nnz(b) > 0
                    idx = sub2ind_(b.sz, b.ind);
                    a(idx) = a(idx) + b.var;
                end
                return
            end
            
            if ~issparse(b)
                a = b + a;
                return
            end
            
            if isempty(b.ind), return; end
            if isempty(a.ind), a = b; return; end
            
            [lia, locb] = ismember(b.ind, a.ind, 'rows');
            a.var(locb(lia)) = a.var(locb(lia)) + b.var(lia);
            a.var = [a.var; b.var(~lia)];
            a.ind = [a.ind; b.ind(~lia, :)];
        end
        
        function C = tensorprod(A, B, dimA, dimB, ca, cb, options)
            arguments
                A SparseTensor
                B SparseTensor
                dimA
                dimB
                ca = false
                cb = false
                options.NumDimensionsA = ndims(A)
            end
            
            szA = size(A, 1:options.NumDimensionsA);
            szB = size(B, 1:max(ndims(B), max(dimB)));
            
            assert(length(dimA) == length(dimB) && all(szA(dimA) == szB(dimB)), ...
                'sparse:dimerror', 'incompatible contracted dimensions.');
            
            uncA = 1:length(szA); uncA(dimA) = [];
            uncB = 1:length(szB); uncB(dimB) = [];
            
            if isempty(uncA)
                if isempty(uncB)
                    szC = [1 1];
                elseif length(uncB) == 1
                    szC = [1 szB(uncB)];
                else
                    szC = szB(uncB);
                end
            elseif isempty(uncB)
                if length(uncA) == 1
                    szC = [szA(uncA) 1];
                else
                    szC = szA(uncA);
                end
            else
                szC = [szA(uncA) szB(uncB)];
            end
            
            A = reshape(permute(A, [uncA dimA]), [prod(szA(uncA)), prod(szA(dimA))]);
            B = reshape(permute(B, [dimB uncB]), [prod(szB(dimB)), prod(szB(uncB))]);
            
            if isempty(uncA) && isempty(uncB)
                C = 0;
                if nnz(A) > 0 && nnz(B) > 0
                    for i = 1:size(A, 1)
                        for j = 1:size(B, 2)
                            for k = 1:size(A, 2)
                                Aind = all(A.ind == [i k], 2);
                                if ~any(Aind), continue; end
                                Bind = all(B.ind == [k j], 2);
                                if ~any(Bind), continue; end
                                
                                C = C + ...
                                    tensorprod(A.var(Aind), B.var(Bind), dimA, dimB, ...
                                    'NumDimensionsA', options.NumDimensionsA);
                            end
                        end
                    end
                end
            else
                Cvar = A.var.empty(0, 1);
                Cind = double.empty(0, length(uncA) + length(uncB));

                if nnz(A) > 0 && nnz(B) > 0
                    for i = 1:size(A, 1)
                        for j = 1:size(B, 2)
                            for k = 1:size(A, 2)
                                Aind = all(A.ind == [i k], 2);
                                if ~any(Aind), continue; end
                                Bind = all(B.ind == [k j], 2);
                                if ~any(Bind), continue; end
                                if ~isempty(Cind) && all(Cind(end,:) == [i j], 2)
                                    Cvar(end) = Cvar(end) + ...
                                        tensorprod(A.var(Aind), B.var(Bind), dimA, dimB, ...
                                        'NumDimensionsA', options.NumDimensionsA);
                                else
                                    Cvar(end+1) = ...
                                        tensorprod(A.var(Aind), B.var(Bind), dimA, dimB, ...
                                        'NumDimensionsA', options.NumDimensionsA);
                                    Cind = [Cind; [i j]];
                                end
                            end
                        end
                    end
                end

                C = reshape(SparseTensor(Cind, Cvar, [size(A,1) size(B,2)]), szC);
                if size(Cind, 1) == prod(szC), C = full(C); end
            end
        end
        
        function t = times(t1, t2)
            if isnumeric(t1)
                if isempty(t2.var)
                    t = t2;
                    return
                end
                t = t2;
                t.var = t1 .* t.var;
                return
            end
            
            if isnumeric(t2)
                t = t2 .* t1;
                return
            end
            
            if isscalar(t1) && ~isscalar(t2)
                t1 = repmat(t1, size(t2));
            elseif isscalar(t2) && ~isscalar(t1)
                t2 = repmat(t2, size(t1));
            end
            
            assert(isequal(size(t1), size(t2)), 'sparse:dimerror', ...
                'incompatible input sizes.');
            
            if ~issparse(t1)
                if isempty(t2.var)
                    t = t2;
                    return
                end
                
                idx = sub2ind_(t2.sz, t2.ind);
                t = t2;
                t.var = t1(idx) .* t.var;
                return
            end
            
            if ~issparse(t2)
                if isempty(t1.var)
                    t = t1;
                    return
                end
                
                idx = sub2ind_(t1.sz, t1.ind);
                t = t1;
                t.var = t.var .* t2(idx);
                return
            end
            
            [inds, ia, ib] = intersect(t1.ind, t2.ind, 'rows');
            t = SparseTensor(inds, t1.var(ia) .* t2.var(ib), t1.sz);
        end
        
        function t = tpermute(t, p, r)
            for i = 1:numel(t.var)
                t.var(i) = tpermute(t.var(i), p, r);
            end
            t = permute(t, p);
        end
        
        function t = twist(t, i)
            if nnz(t) > 0
                t.var = twist(t.var, i);
            end
        end
        
        function a = uminus(a)
            if ~isempty(a.var), a.var = -a.var; end
        end
        
        function a = uplus(a)
        end
    end
    
    
    %% Indexing
    methods
        function i = end(t, k, n)
            if n == 1
                i = prod(t.sz);
                return
            end
            
            assert(n == length(t.sz), 'sparse:index', 'invalid amount of indices.')
            i = t.sz(k);
        end
        
        function t = subsref(t, s)
            assert(strcmp(s(1).type, '()'), 'sparse:index', 'only () indexing allowed');
            
            n = size(s(1).subs, 2);
            if n == 1 % linear indexing
                I = ind2sub_(t.sz, s(1).subs{1});
                s(1).subs = arrayfun(@(x) I(:,x), 1:width(I), 'UniformOutput',false);
            else
                assert(n == size(t.sz, 2), 'sparse:index', ...
                    'number of indexing indices must match tensor size.');
            end
            f = true(size(t.ind, 1), 1);
            newsz = zeros(1, size(s(1).subs, 2));
            
            for i = 1:size(s(1).subs, 2)
                A = s(1).subs{i};
                if strcmp(A, ':')
                    newsz(i) = t.size(i);
                    continue;
                end
                nA = length(A);
                if nA ~= length(unique(A))
                    error("Repeated index in position %i",i);
                end
                if ~isempty(t.ind)
                    B = t.ind(:, i);
                    P = false(max(max(A), max(B)) + 1, 1);
                    P(A + 1) = true;
                    f = and(f, P(B + 1));
                    [~, ~, temp] = unique([A(:); t.ind(f, i)], 'stable');
                    t.ind(f, i) = temp(nA+1:end);
                end
                newsz(i) = nA;
            end
            t.sz = newsz;
            if ~isempty(t.ind)
                t.ind = t.ind(f, :);
                t.var = t.var(f);
            end
            if length(s) > 1
                assert(isscalar(t))
                t = subsref(t.var, s(2:end));
            end
        end
        
        function t = subsasgn(t, s, v)
            assert(strcmp(s(1).type, '()'), 'sparse:index', 'only () indexing allowed');
            
            if length(s(1).subs) == 1
                I = ind2sub_(t.sz, s(1).subs{1});
                s(1).subs = arrayfun(@(x) I(:,x), 1:width(I), 'UniformOutput',false);
            end
            assert(length(s(1).subs) == size(t.sz, 2), 'sparse:index', ...
                'number of indexing indices must match tensor size.');
            
            subsize = zeros(1, size(s(1).subs, 2));
            for i = 1:length(subsize)
                if strcmp(s(1).subs{i}, ':')
                    s(1).subs{i} = 1:t.sz(i);
                elseif islogical(s(1).subs{i})
                    s(1).subs{i} = find(s(1).subs{i}).';
                end
                subsize(i) = length(s(1).subs{i});
            end
            if isscalar(v), v = repmat(v, subsize); end
            subs = combvec(s(1).subs{:}).';
            
            if isempty(t.ind)
                t.ind = subs;
                t.var = v(:);
            else
                for i = 1:size(subs, 1)
                    idx = find(all(t.ind == subs(i, :), 2));
                    if isempty(idx)
                        t.ind = [t.ind; subs];
                        t.var = [t.var; full(v(i))];
                    else
                        t.var(idx) = v(i);
                    end
                end
            end
            t.sz = max(t.sz, cellfun(@max, s(1).subs));
        end
        
        function [I, J, V] = find(t, k, which)
            arguments
                t
                k = []
                which = 'first'
            end
            
            if isempty(t.ind)
                I = [];
                J = [];
                V = [];
                return
            end
            
            [inds, p] = sortrows(t.ind, width(t.ind):-1:1);
            
            if ~isempty(k)
                if strcmp(which, 'first')
                    inds = inds(1:k, :);
                    p = p(1:k);
                else
                    inds = inds(end:-1:end-k+1, :);
                    p = p(end:-1:end-k+1);
                end
            end
            
            if nargout < 2
                I = sub2ind_(t.sz, inds);
                return
            end
            
            subs = sub2sub([t.sz(1) prod(t.sz(2:end))], t.sz, t.ind);
            I = subs(:,1);
            J = subs(:,2);
            
            if nargout > 2
                V = t.var(p);
            end
        end
        
        function t = sortinds(t)
            if isempty(t), return; end
            [t.ind, p] = sortrows(t.ind, width(t.ind):-1:1);
            t.var = t.var(p);
        end
    end
end
