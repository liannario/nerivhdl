library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


package Fixed_32 is

-- Declare constants

	constant NUM_WIDTH: integer := 32;
	constant INTEGER_WIDTH: integer := 22;
	constant FRACTION_WIDTH: integer := 10;
	
	constant INTEGER_BASE: real := 2.0**INTEGER_WIDTH;
	constant FRACTION_BASE : real := 2.0**FRACTION_WIDTH;
	
	constant INTEGER_MAX : real := INTEGER_BASE/2.0-1.0;
	constant INTEGER_MIN : real := -INTEGER_BASE/2.0;
	
	constant BIG_INT_LEN : natural := NUM_WIDTH*2;
	
	subtype fixed is std_logic_vector(NUM_WIDTH-1 downto 0);
	subtype big_integer is std_logic_vector(BIG_INT_LEN-1 downto 0);
	
	function to_fixed(x: real) return fixed;
	function to_fixed(x: integer) return fixed;
	function to_real(x: fixed) return real;
	
	function get_fraction(x: fixed) return std_logic_vector;
	function get_integer(x: fixed) return std_logic_vector;	
	
	function add_f(a, b: fixed) return fixed;
	function sub_f(a, b: fixed) return fixed;
	function mul_f(a, b: fixed) return fixed;
	function div_f(a, b: fixed) return fixed;

	function log2 (x : integer) return integer;
	function calc_div_fraction(a, b: fixed) return std_logic_vector;
	
end Fixed_32;

package body Fixed_32 is
	
	function get_fraction(x: fixed) return std_logic_vector is
	begin
		return x(FRACTION_WIDTH-1 downto 0);
	end get_fraction;
	
	function get_integer(x: fixed) return std_logic_vector is
	begin
		return x(NUM_WIDTH-1 downto FRACTION_WIDTH);
	end get_integer;	
	
	
	function to_real(x: fixed) return real is
	variable result: real;
	variable int: std_logic_vector(INTEGER_WIDTH-1 downto 0);
	variable fract: std_logic_vector(FRACTION_WIDTH-1 downto 0);
	begin
		int := get_integer(x);
		fract := get_fraction(x);
		result := real(conv_integer(sxt(int, NUM_WIDTH))) + real(conv_integer(fract)) / FRACTION_BASE;
		return result;
	end to_real;

	function to_fixed(x: real) return fixed is
	variable x_shifted: real;
	begin
		x_shifted := x * 2.0**FRACTION_WIDTH;
		if x_shifted >= INTEGER_MIN and x_shifted <= INTEGER_MAX then
			return conv_std_logic_vector(integer(x_shifted), NUM_WIDTH);
		else
			return conv_std_logic_vector(0, NUM_WIDTH);
		end if;
	end to_fixed;

	function to_fixed(x: integer) return fixed is
	variable result: fixed;
	variable fract_ext: std_logic_vector(FRACTION_WIDTH-1 downto 0) := ( others => '0');
	begin
		result := conv_std_logic_vector(x, INTEGER_WIDTH) & fract_ext;
		return result;
	end to_fixed;

	function add_f(a, b: fixed) return fixed is
	begin
		return a + b;
	end add_f;

	function sub_f(a, b: fixed) return fixed is
	begin
		return a - b;
	end sub_f;
	
	function mul_f(a, b: fixed) return fixed is
	variable result : big_integer := (others => '0');
	begin
		result := conv_std_logic_vector(conv_integer(a) * conv_integer(b), BIG_INT_LEN);
		result := to_stdlogicvector(to_bitvector(result) srl FRACTION_WIDTH);
		return result(NUM_WIDTH-1 downto 0);
	end mul_f;
	
	function div_f(a, b: fixed) return fixed is
	variable shifted_a, shifted_b: fixed;
	variable abs_a, abs_b, log_a, log_b, int_base, shift : integer;
	variable result : std_logic_vector(NUM_WIDTH-1 downto 0) := (others => '0');
	begin
		abs_a := abs(conv_integer(a));
		abs_b := abs(conv_integer(b));

		if abs_b = 0 then -- divisione per zero
			return to_fixed(0); 
		end if;

		if abs_a < abs_b then
			return result(NUM_WIDTH-1 downto FRACTION_WIDTH) & calc_div_fraction(to_fixed(abs_a), to_fixed(abs_b));
		else
			log_a := log2(abs_a);
			log_b := log2(abs_b);
			
			shift := log_a - log_b;
			
			
--			shifted_a := to_stdlogicvector(to_bitvector(conv_std_logic_vector(abs_a, NUM_WIDTH)) sll (NUM_WIDTH - log_a - 1));
--			shifted_b := to_stdlogicvector(to_bitvector(conv_std_logic_vector(abs_b, NUM_WIDTH)) sll (NUM_WIDTH - log_b - 1));

			shifted_a := "01" & to_stdlogicvector(to_bitvector(conv_std_logic_vector(abs_a, NUM_WIDTH-2)) sll (NUM_WIDTH - log_a - 3));
			shifted_b := "01" & to_stdlogicvector(to_bitvector(conv_std_logic_vector(abs_b, NUM_WIDTH-2)) sll (NUM_WIDTH - log_b - 3));
			
			if shifted_a >= shifted_b then
				shifted_a := to_stdlogicvector(to_bitvector(shifted_a) sll 1);
				shifted_a := shifted_a - shifted_b;
				result(FRACTION_WIDTH) := '1';
			end if;
			
			result(FRACTION_WIDTH-1 downto 0) := calc_div_fraction(shifted_a, shifted_b);
			
			return to_stdlogicvector(to_bitvector(result) sll shift);
		end if;
	end div_f;
	
	-- calcolo della frazione per la divisione a / b
	-- attenzione: a < b altrimenti non funziona
	function calc_div_fraction(a, b: fixed) return std_logic_vector is
	variable fraction: std_logic_vector(FRACTION_WIDTH-1 downto 0) := (others => '0');
	variable a_temp : std_logic_vector(NUM_WIDTH downto 0) := "0" & a;
	variable b_temp : std_logic_vector(NUM_WIDTH downto 0) := "0" & b;
	begin
		for i in fraction'high downto fraction'low loop
			a_temp := to_stdlogicvector(to_bitvector(a_temp) sll 1);					
			if a_temp >= b_temp then
				fraction(i) := '1';
				a_temp := a_temp - b_temp;
			else
				fraction(i) := '0';
			end if;	
		end loop;
		return fraction;
	end calc_div_fraction;
	
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

end Fixed_32;
