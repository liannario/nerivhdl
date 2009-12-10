library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.Fixed_32.all;

entity Fixed_32_Test is
end Fixed_32_Test;

architecture Test of Fixed_32_Test is	

	signal x: fixed := to_fixed(3.141592);
	signal y: fixed := to_fixed(2.717);
	signal o: fixed;
	
	signal x_real, y_real, o_real: real;
	
	begin	
		
		stimulus: process begin
			wait for 20ns;
			o <= add_f(x, y);
			wait for 20ns;
			o <= sub_f(x, y);
			wait for 20ns;
			o <= mul_f(x, y);
			wait for 20ns;
			o <= div_f(x, y);
		end process;

		
		x_real <= to_real(x);
		y_real <= to_real(y);
		o_real <= to_real(o);
		
	end Test;

