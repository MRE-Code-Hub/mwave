%{ 
mwave - A water wave and wave energy converter computation package 
Copyright (C) 2014  Cameron McNatt

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

Contributors:
    C. McNatt
%}
classdef IWaves < handle
    
    properties (Constant)
        G = 9.806650;
    end
    
    properties (Access = protected)
        a;
        epsilon;
        t;
        nT;
        beta;
        f;
        omega;
        k;
        lambda;
        h;
        coefs;
    end

    properties (Dependent)
        A;          % Amplitudes (m)
        Epsilon;    % Phases (rad)
        Beta;       % Primary wave directions (rad)
        UniformDir; % Indicates whether all directions are the same
        T;          % Periods (s)
        F;          % Frequencies (Hz)
        Omega;      % Radial Frequencies (rad/s)
        K;          % Wavenumbers (1/m)
        Lambda;     % Wavelengths (m)
        H;          % Water depth (m)
        C;          % Phase Speeds
        Cg;         % Group Velocities
        DepthType;  % Shallow, deep or intermediate
        Count;     % The number of wave periods
    end
    
    properties (Abstract)
       IsIncident;      % Indicates whether it is an incident wave.
       IsPlane;         % Indicates whether it is a long-crested plane wave  
       Mlim;            % Truncation values of the circular coefficient for the circular modes. 
       L;               % Truncation values of the circular coefficients for the evanescent modes. 
       KochinFunc;      % The Kochin function is the far-field amplitude as a function of direction.
    end
    
    methods (Abstract)
        IncAmps(wav, M, varargin);     % Circular coefficients describing the wave.
    end

    methods        
        % A
        function [A] = get.A(wav)
            A = wav.a;
        end
        function [wav] = set.A(wav, a)
            a = wav.checkValues(a);
            if any(a < 0)
                error('The parameter, A, must be greater than 0');
            end
            wav.a = a;
        end
        
        % Epsilon
        function [Epsilon] = get.Epsilon(wav)
            Epsilon = wav.epsilon;
        end
        function [wav] = set.Epsilon(wav, epsilon)
            epsilon = wav.checkValues(epsilon);
            wav.epsilon = epsilon;
        end
        
        % Beta
        function [Beta] = get.Beta(wav)
            Beta = wav.beta;
        end
        function [wav] = set.Beta(wav, beta)
            beta = wav.checkValues(beta);
            wav.beta = beta;
        end
        
        function [ud] = get.UniformDir(wav)
            % Inidcates whether all waves have the same primary direction.
            if all(abs(wav.beta - wav.beta(1)) < 1e-8)
                ud = true;
            else
                ud = false;
            end
        end
        
        % T
        function [T] = get.T(wav)
            % Period
            T = wav.t;
        end
        function [wav] = set.T(wav, t)
            t = wav.checkValues(t);
            wav.t = t;
            wav.f = 1./t;
            wav.omega = 2*pi*wav.f;
            wav.k = IWaves.SolveForK(wav.omega, wav.h);
            wav.lambda = 2*pi./wav.k;
        end
        
        % F
        function [F] = get.F(wav)
            F = wav.f;
        end
        function [wav] = set.F(wav, f)
            f = wav.checkValues(f);
            wav.f = f;
            wav.t = 1./f;
            wav.omega = 2*pi*f;   
            wav.k = IWaves.SolveForK(wav.omega, wav.h);
            wav.lambda = 2*pi./wav.k;
        end
        
        % Omega
        function [Omega] = get.Omega(wav)
            Omega = wav.omega;
        end
        function [wav] = set.Omega(wav, omega)
            omega = wav.checkValues(omega);
            wav.omega = omega;
            wav.f = omega/(2*pi);
            wav.t = 1./wav.f;
            wav.k = IWaves.SolveForK(wav.omega, wav.h);
            wav.lambda = 2*pi./wav.k;
        end
        
        % K
        function [K] = get.K(wav)
            K = wav.k;
        end
        function [wav] = set.K(wav, k)
            k = wav.checkValues(k);
            wav.k = k;
            wav.lambda = 2*pi./k;
            wav.omega = IWaves.SolveForOmega(wav.k, wav.h);
            wav.f = wav.omega/(2*pi);
            wav.t = 1./wav.f;
        end
        
        % Lambda
        function [Lambda] = get.Lambda(wav)
            Lambda = wav.lambda;
        end
        function [wav] = set.Lambda(wav, lambda)
            lambda = wav.checkValues(lambda);
            wav.lambda = lambda;
            wav.k = 2*pi./lambda;
            wav.omega = IWaves.SolveForOmega(wav.k, wav.h);
            wav.f = wav.omega/(2*pi);
            wav.t = 1./wav.f;
        end
        
        % H
        function [H] = get.H(wav)
            H = wav.h;
        end
        function [wav] = set.H(wav, h)
            if (length(h) > 1)
                error('The parameter, h, must be a scalar value');
            end
            wav.h = h;
            if (~isempty(wav.omega))
                wav.k = IWaves.SolveForK(wav.omega, h);
                wav.lambda = 2*pi./wav.k;
            end
        end
        
        % C
        function [C] = get.C(wav)
            C = wav.omega./wav.k;
        end
        
        % Cg
        function [Cg] = get.Cg(wav)
            Cg = IWaves.GroupVel(wav.T, wav.H);
        end
        
        % DepthType
        function [type] = get.DepthType(wav)
            lamh = wav.lambda./wav.h;
            
            if (lamh < 2)
                type = 'Deep';
            elseif (lamh > 20)
                type = 'Shallow';
            else
                type = 'Intermediate';
            end
        end
        
        % Count
        function [n_] = get.Count(wav)
            n_ = wav.nT;
        end
        
        % Energy
        function [e] = Energy(wav, rho)
            e = 0.5*rho*[wav.G].*[wav.a].^2;
        end
        
         % Flux
        function [f] = EnergyFlux(wav, rho)
            f = [wav.Cg].*[wav.Energy(rho)];
        end
        
        function [as] = ShoalTo(wav, h)
            nCg = IWaves.GroupVel(wav.T, h);
            as = wav.A.*sqrt(wav.Cg./nCg);
        end
    end
    
    methods (Access = protected)
        
        function [] = init(wav, a, t, beta, h, varargin)
            
            wav.t = wav.checkValues(t);
            
            if (length(a) == 1)
                a = a*ones(size(wav.t));
            end
            
            if (length(beta) == 1)
                beta = beta*ones(size(wav.t));
            end
            
            wav.a = wav.checkValues(a);
            wav.beta = wav.checkValues(beta);
            
            if (length(h) > 1)
                error('Water depth must be a scalar input');
            end
            wav.h = h;
            
            if (isempty(varargin))
                wav.epsilon = zeros(wav.nT, 1);
            else
                wav.epsilon = wav.checkValues(varargin{1});
            end
            
            wav.f = 1./wav.t;
            wav.omega = 2*pi*wav.f;
            wav.k = IWaves.SolveForK(wav.omega, h);
            wav.lambda = 2*pi./wav.k;
        end
        
        function [val] = checkValues(wav, val)
            if (isvector(val))
                if (isrow(val))
                    val = val.';
                end
            else
                error('Input values not the correct size');
            end
            if (wav.nT < 1)
                wav.nT = length(val);
            elseif (length(val) ~= wav.nT)
                error('Input values not the correct size');
            end
        end
        
    end
    methods (Static)
        
        function [cg] = GroupVel(T, h)
            g = IWaves.G;
            if (isinf(h))
                nn = 0.5;
                c = g./(2*pi)*T;
            else
                lam = IWaves.T2Lam(T, h, g);
                k_ = 2*pi./lam;
                nn = 0.5*(1 + 2*k_*h./sinh(2*k_*h));
                c = 2*pi./(T.*k_);
            end
            cg = nn.*c;            
        end
        
        function [Ef] = UnitEnergyFlux(rho, T, h)
            g = 9.806650;
            e = 0.5*rho*g;
            cg = IWaves.GroupVel(T, h);
            Ef = e*cg;
        end
        
        function [lambda] = T2Lam(T, h, varargin)
            % Solves for wavelength with depth and period.  
            
            g = IWaves.G;            
            omeg = 2*pi./T;
            k_ = IWaves.SolveForK(omeg, h);
            lambda = 2*pi./k_;            
        end
        
        function [T] = Lam2T(lambda, h)
            % Solves for period with depth and wavelength. 
            
            g = IWaves.G;            
            k_ = 2*pi./lambda;
            omeg = IWaves.SolveForOmega(k_, h);
            T = 2*pi./omeg;
        end
     
        function [k] = SolveForK(omega, h, varargin)
            % k = SolveForK(omega, h)
            % solves for the wavenumber as a function of radial wave frequency (omega)
            % and depth (h).
            %
            % 
            % Optional argument is 'Evanenscent' which request the
            % evanescent wave numbers as well.  If 'Evanenscent' modes are
            % requested the following argument must be an integer which is
            % the number of requested evanescent wave numbers.

            g = IWaves.G;
            
            L_ = [];
            [opts, args] = checkOptions({{'Evanescent', 1}}, varargin);
            if opts(1)
                L_ = args{1};
            end
            
            k = solveForK(omega, h, g, L_);
        end
        
        function [omega] = SolveForOmega(k, h)
            
            g = IWaves.G;
            
            if (isempty(k) || isempty(h))
                error('Empty parameters in IWaves.SolveForOmega.');
            end
            
            if (h <= 0)
                error('The depth must be greater than 0');
            elseif (h == Inf)
                omega = sqrt(g*k);
            else
                omega = sqrt(g*k.*tanh(k*h));
            end
        end
    end
    
end

