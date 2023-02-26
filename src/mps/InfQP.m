classdef InfQP
    % Infinite Quasi-Particle states
    
    
    %% Properties
    properties
        mpsleft  UniformMps
        mpsright UniformMps
        X
        VL
        B
        p
    end
    
    
    %% Constructors
    methods
        function qp = InfQP(varargin)
            if nargin == 0, return; end
            
            qp.mpsleft  = varargin{1};
            qp.mpsright = varargin{2};
            qp.X    = varargin{3};
            qp.VL   = varargin{4};
            qp.B    = varargin{5};
            qp.p    = varargin{6};
        end
    end
    
    methods (Static)
        function qp = new(fun, mpsleft, mpsright, p, charge)
            arguments
                fun                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 
                mpsleft
                mpsright = []
                p = 0
                charge = []
            end
            
            if isempty(mpsright), mpsright = mpsleft; end
            assert(period(mpsleft) == period(mpsright));
            
            dims = struct;
            dims.charges = charge;
            dims.degeneracies = ones(size(charge));
            
            AL = mpsleft.AL;
            for i = period(mpsleft):-1:1
                VL(i) = leftnull(AL(i));
                rVspace = rightvspace(mpsleft, i);
                lVspace = leftvspace(mpsright, i);
                if isempty(charge)
                    aspace = one(rVspace);
                else
                    aspace = rVspace.new(dims, false);
                end
                X(i) = Tensor.new(fun, rVspace', [aspace lVspace]);
            end
            
            qp = InfQP(mpsleft, mpsright, X, VL, [], p);
            qp.B = computeB(qp);
        end
        
        function qp = randnc(varargin)
            qp = InfQP.new(@randnc, varargin{:});
        end
    end
    
    
    %% Derived Properties
    methods
        function s = auxspace(qp, i)
            s = space(qp.X(i), 3);
        end
        
        function al = AL(qp, sites)
            if nargin > 1
                al = qp.mpsleft.AL(sites);
            else
                al = qp.mpsleft.AL;
            end
        end
        
        function ar = AR(qp, sites)
            if nargin > 1
                ar = qp.mpsright.AR(sites);
            else
                ar = qp.mpsright.AR;
            end
        end
        
        function B = computeB(qp)
            if ~isempty(qp.B), B = qp.B; return; end
            for w = period(qp):-1:1
                B(w) = multiplyright(qp.VL(w), qp.X(w));
            end
        end
        
        function bool = istrivial(qp)
            bool = qp.p == 0 && istrivial(auxspace(qp, 1));
        end
    end
    
    methods
        function p = period(qp)
            p = length(qp.X);
        end
        
        function type = underlyingType(qp)
            type = underlyingType(qp.X);
        end
    end
end
