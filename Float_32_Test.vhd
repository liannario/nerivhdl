library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Float_32.all;

entity Float_32_Test is
end Float_32_Test;

architecture Test of Float_32_Test is
	type real_array is array(natural range <>) of real;

	signal x: float_32 := to_float(0.0);
	signal y: float_32 := to_float(0.0);
	signal o: float_32;
	
	signal x_real, y_real, o_real: real;

	begin	
		
		stimulus: process 
		constant x_a: real_array(1 to 10) := ( -1000.0, 100.0, 3.141592, 2.717, 1.414,
															2.0**20, 76.321, 6.28, 1.1*10**7, 1231.0		
															);

		constant y_a: real_array(10 downto 1) := ( 2.0**20, 100.0, 3.141592, 2.717, 1.414,
															2.0**20, 76.321, 6.28, 1.1*10**7, 1231.0		
															);
		type counter_type is range x_a'low to x_a'high;
		variable counter: counter_type := counter_type'low;
		begin
			x <= to_float(x_a(natural(counter)));
			y <= to_float(y_a(natural(counter)));
			wait for 20ns;			
			o <= add_f_synth(x, y);
			wait for 20ns;					
			o <= sub_f_synth(x, y);
			wait for 20ns;
			o <= mul_f_synth(x, y);
			wait for 20ns;
			o <= div_f_synth(x, y);
			counter := counter + 1;
		end process;

		
		x_real <= to_real(x);
		y_real <= to_real(y);
		o_real <= to_real(o);
		
	end Test;

