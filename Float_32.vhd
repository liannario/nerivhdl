library ieee;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

package Float_32 is

-- Declare constants

	constant NUM_WIDTH : integer := 32;
	constant EXP_WIDTH : integer := 6;
	constant FRACTION_WIDTH : integer := 25;
	
	constant EXP_RANGE : integer := 2**EXP_WIDTH;
	
	constant FRACTION_BASE: real := 2.0**FRACTION_WIDTH;
	constant EXP_BASE: integer := EXP_RANGE / 2 - 1;
	
	constant EXP_MAX: integer := EXP_RANGE - EXP_BASE - 1;
	constant EXP_MIN: integer := 0 - EXP_BASE;
	
	constant REAL_ZERO: real := 0.0;
	constant REAL_POS_ZERO : real := 2.0**EXP_MIN;
	constant REAL_NEG_ZERO : real := -2.0**EXP_MIN;
	constant REAL_POS_INFINITY : real := 2.0**EXP_MAX;
	constant REAL_NEG_INFINITY : real := -2.0**EXP_MAX;

	subtype float_32 is std_logic_vector(NUM_WIDTH-1 downto 0);
	
	subtype exp_32 is std_logic_vector(EXP_WIDTH-1 downto 0);
	subtype fraction_32 is std_logic_vector(FRACTION_WIDTH-1 downto 0);
	
	subtype extended_float_32 is std_logic_vector(EXP_RANGE-1 downto 0);
	subtype extended_fraction_32 is std_logic_vector(FRACTION_WIDTH*2+1 downto 0);
	
	constant FLOAT_POS_ZERO : float_32 := X"00000000";
	constant FLOAT_NEG_ZERO : float_32 := X"80000000";
	constant FLOAT_POS_INFINITY : float_32 := X"7F800000";
	constant FLOAT_NEG_INFINITY : float_32 := X"FF800000";

	
-- Declare functions and procedure

	function to_float (x: real) return float_32;
	function to_real(x: float_32) return real;
	
	function extend(x: float_32) return extended_float_32;
	function reduce(x: extended_float_32; sign: std_logic) return float_32;
	
	function add_f_synth(x, y: float_32) return float_32;
	function sub_f_synth(x, y: float_32) return float_32;
	function mul_f_synth(x, y: float_32) return float_32;
	function div_f_synth(x, y: float_32) return float_32;
	
	function add_f(x, y: float_32) return float_32;
	function sub_f(x, y: float_32) return float_32;
	function mul_f(x, y: float_32) return float_32;
	function div_f(x, y: float_32) return float_32;	

	function log2(x : integer) return integer;

	function extended_float_slice(x: extended_float_32; size, high, low: integer) return std_logic_vector;	
	
	function calculate_exp_mul(exp_x, exp_y: exp_32) return exp_32;
	function calculate_exp_div(exp_x, exp_y: exp_32) return exp_32;
	
end Float_32;

package body Float_32 is
	
	function to_float (x: real) return float_32 is
	variable result : float_32;
	variable exp, fraction: integer;
	variable sign: std_logic;
	begin
		if x = REAL_ZERO or ( x <= REAL_POS_ZERO and x >= REAL_NEG_ZERO ) then
			return FLOAT_POS_ZERO;
		elsif x >= REAL_POS_INFINITY then
			return FLOAT_POS_INFINITY;
		elsif x <= REAL_NEG_INFINITY then
			return FLOAT_NEG_INFINITY;
		else
			for i in (EXP_MIN + 1) to (EXP_MAX - 1) loop
				if (abs(x) / 2.0**i) >= 1.0 and (abs(x) / 2.0**i) < 2.0 then
					exp := i;
					exit;
				end if;				
			end loop;
			
			fraction := integer((abs(x) - 2.0**exp)/(2.0**exp)*FRACTION_BASE);
			
			if x > REAL_ZERO then
				sign := '0';
			else
				sign := '1';
			end if;

			result := sign & conv_std_logic_vector(exp + EXP_BASE, EXP_WIDTH) 
						& conv_std_logic_vector(fraction, FRACTION_WIDTH);
				
			return result;
			
		end if;
	end to_float;
	
	function to_real(x: float_32) return real is
	alias sgn is x(NUM_WIDTH-1);
	alias exp is x(NUM_WIDTH-2 downto FRACTION_WIDTH);
	alias fract is x(FRACTION_WIDTH-1 downto 0);
	variable result: real;
	begin
		if x = FLOAT_POS_ZERO or  x = FLOAT_NEG_ZERO then
			return REAL_ZERO;
		elsif x = FLOAT_POS_INFINITY then
			return REAL_POS_INFINITY;
		elsif x = FLOAT_NEG_INFINITY then
			return REAL_NEG_INFINITY;
		else
			if sgn = '0' then
				result := 1.0;
			else
				result := -1.0;
			end if;
			
			result := result * 2.0**(conv_integer(exp)-EXP_BASE) * ( 1.0 + real(conv_integer(fract)) / FRACTION_BASE );
			
			return result;
		end if;
	end function;

	function extend(x: float_32) return extended_float_32 is
	alias exp is x(NUM_WIDTH-2 downto FRACTION_WIDTH);
	alias fract is x(FRACTION_WIDTH-1 downto 0);
	variable result : extended_float_32 := (others => '0');
	variable normalized_exp : integer;
	begin
		result(EXP_BASE downto EXP_BASE-FRACTION_WIDTH) := "1" &  fract;
		normalized_exp := conv_integer(exp) - EXP_BASE;
		
		if normalized_exp > 0 then
			result := to_stdlogicvector(to_bitvector(result) sll normalized_exp);
		else
			result := to_stdlogicvector(to_bitvector(result) srl -normalized_exp);
		end if;
		
		return result;
	end extend;
	
	function reduce(x: extended_float_32; sign: std_logic) return float_32 is
	variable result: float_32;
	variable temp: extended_float_32;
	variable normalized_exp: integer := 0;
	begin
		temp := x;
		
		if temp(temp'high) = '1' then
			if sign = '0' then
				return FLOAT_POS_INFINITY;
			else
				return FLOAT_NEG_INFINITY;
			end if;
		end if;
		
		for i in temp'high downto temp'low loop
			if temp(i) = '1' then
				normalized_exp := i - EXP_BASE;
				exit;
			end if;
		end loop;
		
		if normalized_exp = EXP_MIN then
			if sign = '0' then
				return FLOAT_POS_ZERO;
			else
				return FLOAT_NEG_ZERO;
			end if;
		end if;
		
		if normalized_exp > 0 then
			temp := to_stdlogicvector(to_bitvector(temp) srl normalized_exp);
		elsif normalized_exp < 0 then
			temp := to_stdlogicvector(to_bitvector(temp) sll -normalized_exp);
		end if;
		
		result(NUM_WIDTH-1) := sign;
		result(NUM_WIDTH-2 downto FRACTION_WIDTH) := conv_std_logic_vector(normalized_exp + EXP_BASE, EXP_WIDTH);
		result(FRACTION_WIDTH-1 downto 0) := conv_std_logic_vector(conv_integer(temp(EXP_BASE-1 downto EXP_BASE-FRACTION_WIDTH)),
														FRACTION_WIDTH);
		
		return result;
		
	end reduce;

	function add_f_synth(x, y: float_32) return float_32 is
	alias sgn_x is x(NUM_WIDTH-1);
	alias sgn_y is y(NUM_WIDTH-1);	
	variable ext_x, ext_y: extended_float_32 := (others => '0');
	variable result: float_32;
	variable sign: std_logic;
	begin
		
		ext_x := extend(x);
		ext_y := extend(y);
		
		if sgn_x = '0' and sgn_y = '0' then -- tutti e due positivi
			return reduce(ext_x + ext_y, '0');
		elsif sgn_x = '0' and sgn_y = '1' then  -- x positivo e y negativo
			if ext_x >= ext_y then --risultato positivo
				return reduce(ext_x - ext_y, '0');
			else -- risultato negativo
				return reduce(ext_y - ext_x, '1');
			end if;
		elsif sgn_x = '1' and sgn_y = '0' then -- x negativo e y positivo
			if ext_x >= ext_y then --risultato negativo
				return reduce(ext_x - ext_y, '1');
			else -- risultato positivo
				return reduce(ext_y - ext_x, '0');
			end if;
		else -- tutti e due negativi
			return reduce(ext_x + ext_y, '1');
		end if;
		
	end add_f_synth;
	
--	function add_f_synth(x, y: float_32) return float_32 is
--	alias sgn_x is x(NUM_WIDTH-1);
--	alias sgn_y is y(NUM_WIDTH-1);
--	alias exp_x is x(NUM_WIDTH-2 downto FRACTION_WIDTH);
--	alias exp_y is y(NUM_WIDTH-2 downto FRACTION_WIDTH);		
--	alias fraction_x is x(FRACTION_WIDTH-1 downto 0);
--	alias fraction_y is y(FRACTION_WIDTH-1 downto 0);
--	
--	variable result_sgn : std_logic := '0';
--	variable result_exp : exp_32 := (others => '0');
--	variable result_fraction: fraction_32 := (others => '0');
--		
--	variable result, major, minor : extended_float_32 := (others => '0');
--	variable exp_major, exp_minor : exp_32 := (others => '0');
--	variable fraction_major, fraction_minor: fraction_32;
--	variable sgn_major, sgn_minor: std_logic := '0';
--	
--	variable shift: natural := 0;
--	
--	begin
--		
--		if exp_x > exp_y then -- x > y
--			sgn_major := sgn_x; exp_major := exp_x; fraction_major := fraction_x;
--			sgn_minor := sgn_y; exp_minor := exp_y; fraction_minor := fraction_y;
--		elsif exp_x < exp_y then -- x < y
--			sgn_major := sgn_y; exp_major := exp_y; fraction_major := fraction_y;
--			sgn_minor := sgn_x; exp_minor := exp_x; fraction_minor := fraction_x;
--		else -- esponenti uguali, confronto le frazioni
--			if fraction_x > fraction_y then -- x > y
--				sgn_major := sgn_x; exp_major := exp_x; fraction_major := fraction_x;
--				sgn_minor := sgn_y; exp_minor := exp_y; fraction_minor := fraction_y;
--			else -- x <= y
--				sgn_major := sgn_y; exp_major := exp_y; fraction_major := fraction_y;
--				sgn_minor := sgn_x; exp_minor := exp_x; fraction_minor := fraction_x;
--			end if;
--		end if;
--		
--		result_sgn := sgn_major;
--		
--		shift := conv_integer(exp_major - exp_minor);
--		
--		major(EXP_RANGE-2 downto EXP_RANGE-FRACTION_WIDTH-2) := "1" & fraction_major;
--		minor(EXP_RANGE-2 downto EXP_RANGE-FRACTION_WIDTH-2) := "1" & fraction_minor;
--		minor := to_stdlogicvector((to_bitvector(minor) srl shift));
--		
--		if ( sgn_major xnor sgn_minor ) = '1' then
--			result := major + minor;
--		else
--			result := major - minor;
--		end if;
--		
--		for i in EXP_RANGE-1 downto 0 loop
--			if result(EXP_RANGE-1) = '1' then
--				result_exp := exp_major - (EXP_RANGE - i - 1) + 1;
--				exit;
--			else
--				result := to_stdlogicvector(to_bitvector(result) sll 1);
--			end if;
--		end loop;
--		
--		result_fraction := result(EXP_RANGE-2 downto EXP_RANGE-FRACTION_WIDTH-1);
--		
--		return result_sgn & result_exp & result_fraction;
--		
--	end add_f_synth;
	
	function sub_f_synth(x, y: float_32) return float_32 is
	variable not_y: float_32;
	begin
		not_y := not(y(NUM_WIDTH-1)) & y(NUM_WIDTH-2 downto 0);
		return add_f_synth(x, not_y);
	end sub_f_synth;
	
	function mul_f_synth(x, y: float_32) return float_32 is	
	alias sgn_x is x(NUM_WIDTH-1);
	alias sgn_y is y(NUM_WIDTH-1);
	alias exp_x is x(NUM_WIDTH-2 downto FRACTION_WIDTH);
	alias exp_y is y(NUM_WIDTH-2 downto FRACTION_WIDTH);		
	alias fraction_x is x(FRACTION_WIDTH-1 downto 0);
	alias fraction_y is y(FRACTION_WIDTH-1 downto 0);

	variable result_sgn: std_logic := '0';
	variable result_exp : exp_32 := (others => '0');
	variable result_fraction: fraction_32 := (others => '0');

	variable ext_fraction: extended_fraction_32;

	variable rounding_bit : std_logic := '0';
	
	begin
		result_sgn := sgn_x xor sgn_y;
		result_exp := calculate_exp_mul(exp_x, exp_y);
		ext_fraction := ("1" & fraction_x) * ("1" & fraction_y);

		if ext_fraction(ext_fraction'length-1) = '1' then
			result_exp := result_exp + 1;
			result_fraction := ext_fraction(ext_fraction'length-2 downto ext_fraction'length-FRACTION_WIDTH-1);
			rounding_bit := ext_fraction(ext_fraction'length-FRACTION_WIDTH-2);
		else
			result_fraction := ext_fraction(ext_fraction'length-3 downto ext_fraction'length-FRACTION_WIDTH-2);
			rounding_bit := ext_fraction(ext_fraction'length-FRACTION_WIDTH-3);
		end if;
		
		result_fraction := result_fraction + rounding_bit;
		
		return result_sgn & result_exp & result_fraction;
		
	end mul_f_synth;
	
	function div_f_synth (x, y: float_32) return float_32 is

	type iteration_type is range 0 to FRACTION_WIDTH;

	alias sgn_x is x(NUM_WIDTH-1);
	alias sgn_y is y(NUM_WIDTH-1);
	alias exp_x is x(NUM_WIDTH-2 downto FRACTION_WIDTH);
	alias exp_y is y(NUM_WIDTH-2 downto FRACTION_WIDTH);		
	alias fraction_x is x(FRACTION_WIDTH-1 downto 0);
	alias fraction_y is y(FRACTION_WIDTH-1 downto 0);

	variable result_sgn: std_logic := '0';
	variable result_exp : exp_32 := (others => '0');
	variable result_fraction: fraction_32 := (others => '0');

	variable fraction_divider, fraction_divisor, fraction_result : std_logic_vector(FRACTION_WIDTH+2 downto 0); 
	
	begin

		result_sgn := sgn_x xor sgn_y;
		result_exp := calculate_exp_div(exp_x, exp_y);

		fraction_divider := "01" & fraction_x & "0";
		fraction_divisor := "01" & fraction_y & "0";
		fraction_result := (others => '0');
		
		for i in FRACTION_WIDTH downto 0 loop
			if fraction_divider >= fraction_divisor then
				fraction_result(integer(i)) := '1';
				fraction_divider := fraction_divider - fraction_divisor;
			else
				fraction_result(integer(i)) := '0';
			end if;
			fraction_divider := to_stdlogicvector(to_bitvector(fraction_divider) sll 1);			
		end loop;
		
		if fraction_result(FRACTION_WIDTH) = '0' then -- esponente da normalizzare
			result_exp := result_exp - 1;
			result_fraction := to_stdlogicvector(to_bitvector(fraction_result) sll 1)(FRACTION_WIDTH-1 downto 0);
		else
			result_fraction := fraction_result(FRACTION_WIDTH-1 downto 0);
		end if;		

		return result_sgn & result_exp & result_fraction;
		
	end div_f_synth;
	
	function add_f(x, y: float_32) return float_32 is
	begin
		return to_float(to_real(x) + to_real(y));
	end add_f;

	function sub_f(x, y: float_32) return float_32 is
	begin
		return to_float(to_real(x) - to_real(y));
	end sub_f;

	function mul_f(x, y: float_32) return float_32 is
	begin
		return to_float(to_real(x) * to_real(y));
	end mul_f;

	function div_f(x, y: float_32) return float_32 is
	begin
		return to_float(to_real(x) / to_real(y));
	end div_f;

	function log2 (x : integer) return integer is
	variable l: integer := 30;
	begin
		for i in 1 to 30 loop
			if (2**i > x) then 
				l := i - 1;
				exit;
			end if;
		end loop;
		return l ;
	end log2;

	function extended_float_slice(x: extended_float_32; size, high, low: integer) return std_logic_vector is
	variable result : std_logic_vector(size-1 downto 0);
	begin
		result := x(high downto low);
		return result;
	end extended_float_slice;
	
	function calculate_exp_mul(exp_x, exp_y: exp_32) return exp_32 is
	variable result : integer := conv_integer(exp_x) + conv_integer(exp_y) - EXP_BASE;
	begin
		if result > (EXP_MAX + EXP_BASE) then
			return conv_std_logic_vector(EXP_MAX + EXP_BASE, EXP_WIDTH);
		elsif result < 0 then
			return conv_std_logic_vector(0, EXP_WIDTH);
		else
			return conv_std_logic_vector(result, EXP_WIDTH);
		end if;
	end calculate_exp_mul;

	function calculate_exp_div(exp_x, exp_y: exp_32) return exp_32 is
	variable result : integer := conv_integer(exp_x) - conv_integer(exp_y) + EXP_BASE;
	begin
		if result > (EXP_MAX + EXP_BASE) then
			return conv_std_logic_vector(EXP_MAX + EXP_BASE, EXP_WIDTH);
		elsif result < 0 then
			return conv_std_logic_vector(0, EXP_WIDTH);
		else
			return conv_std_logic_vector(result, EXP_WIDTH);
		end if;
	end calculate_exp_div;
	
end Float_32;
