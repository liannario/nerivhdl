library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

package Global is
-- ***********************************************************************************************
--														GENERALI
-- ***********************************************************************************************
	-- parallelismo
	constant PARALLELISM: integer := 32;
	
	-- program counter
	constant PC_BITS: integer := PARALLELISM-2; -- lunghezza del pc in bit 
	constant PC_EXT: std_logic_vector(PARALLELISM-PC_BITS-1 downto 0) := (others => '0'); -- per estendere 
																													  -- il program counter
	-- register file
	constant NUM_REGISTERS: integer := 32; -- numero di registri del RF
	constant REGISTER_ADDR_LEN: integer := 5; -- numero di bit necessari per indirizzare un registro
	type register_file_type is array(0 to NUM_REGISTERS-1) of std_logic_vector(PARALLELISM-1 downto 0); -- register file
	
	-- memoria
	type eprom_type is array(integer range <>) of std_logic_vector(PARALLELISM-1 downto 0); -- eprom
	type ram_type is array(natural range <>) of std_logic_vector(7 downto 0);
	
	-- simulazioni
	constant TIME_UNIT: time := 30ns; -- nelle simulazioni = periodo di clock

-- ***********************************************************************************************
--														SET DI ISTRUZIONI
-- ***********************************************************************************************
--	Instr.	Description								Format	Opcode	Operation (C-style coding)
--	ADD		add										R			0x20		Rd = Rs1 + Rs2
--	ADDI		add immediate							I			0x08		Rd = Rs1 + extend(immediate)
--	AND		and										R			0x24		Rd = Rs1 & Rs2
--	ANDI		and immediate							I			0x0c		Rd = Rs1 & immediate
--	BEQZ		branch if equal to zero				I			0x04		PC += (Rs1 == 0 ? extend(immediate) : 0)
--	BNEZ		branch if not equal to zero		I			0x05		PC += (Rs1 != 0 ? extend(immediate) : 0)
--	J			jump										J			0x02		PC += extend(value)
--	JAL		jump and link							J 			0x03		R31 = PC + 4 ; PC += extend(value)
--	JALR		jump and link register				I			0x13		R31 = PC + 4 ; PC = Rs1
--	JR			jump register							I			0x12		PC = Rs1
--	LHI		load high bits							I			0x0f		Rd = immediate << 16
--	LW			load woRd								I			0x23		Rd = MEM[Rs1 + extend(immediate)]
--	OR			or											R			0x25		Rd = Rs1 | Rs2
--	ORI		or immediate							I			0x0d		Rd = Rs1 | immediate
--	SEQ		set if equal							R			0x28		Rd = (Rs1 == Rs2 ? 1 : 0)
--	SEQI		set if equal to immediate			I			0x18		Rd = (Rs1 == extend(immediate) ? 1 : 0)
--	SLE		set if less than or equal			R			0x2c		Rd = (Rs1 <= Rs2 ? 1 : 0)
--	SLEI		set if less than or equal imm		I			0x1c		Rd = (Rs1 <= extend(immediate) ? 1 : 0)
--	SLL		shift left logical					R			0x04		Rd = Rs1 << (Rs2 % 8)
-- SLLI		shift left logical immediate		I			0x14		Rd = Rs1 << (immediate % 8)
-- SLT		set if less than						R			0x2a		Rd = (Rs1 < Rs2 ? 1 : 0)
--	SLTI		set if less than immediate			I			0x1a		Rd = (Rs1 < extend(immediate) ? 1 : 0)
-- SNE		set if not equal						R			0x29		Rd = (Rs1 != Rs2 ? 1 : 0)
--	SNEI		set if not equal to immediate		I			0x19		Rd = (Rs1 != extend(immediate) ? 1 : 0)
-- SRA		shift right arithmetic				R			0x07		as SRL & see below
-- SRAI		shift right arithmetic immediate	I			0x17		as SRLI & see below
--	SRL		shift right logical					R			0x06		Rd = Rs1 >> (Rs2 % 8)
-- SRLI		shift right logical immediate		I			0x16		Rd = Rs1 >> (immediate % 8)
-- SUB		subtract									R			0x22		Rd = Rs1 - Rs2
-- SUBI		subtract immediate					I			0x0a		Rd = Rs1 - extend(immediate)
--	SW			store word								I			0x2b		MEM[Rs1 + extend(immediate)] = Rd
--	XOR		exclusive or							R			0x26		Rd = Rs1 ^ Rs2
-- XORI		exclusive or immediate				I			0x0e		Rd = Rs1 ^ immediate

	type instruction_array is array(integer range <>) of std_logic_vector(5 downto 0); 

-- tipi di istruzioni
	constant IF_R: std_logic_vector := "000"; -- tipo R
	constant IF_I: std_logic_vector := "001"; -- tipo I
	constant IF_J: std_logic_vector := "010"; -- tipo J
	constant IF_F: std_logic_vector := "011"; -- tipo F
	constant IF_IF: std_logic_vector := "100"; -- tipo IF
	constant IF_NOP: std_logic_vector := "111"; -- No operation
	
-- codici operativi
	
-- generali
	constant NOP: std_logic_vector(5 downto 0) := "111111"; -- codice operativo alto NOP
	constant OPCODE_HIGH_R: std_logic_vector(5 downto 0) := "000000"; -- codice operativo alto R
	constant OPCODE_HIGH_F: std_logic_vector(5 downto 0) := "000001"; -- codice operativo alto F
	
-- tipo R
	constant R_ADD: std_logic_vector(5 downto 0) := "100000"; 
	constant R_AND: std_logic_vector(5 downto 0) := "100100";
	constant R_OR: std_logic_vector(5 downto 0) := "100101";
	constant R_SEQ: std_logic_vector(5 downto 0) := "101000";
	constant R_SLE: std_logic_vector(5 downto 0) := "101100";
	constant R_SLL: std_logic_vector(5 downto 0) := "000100";
	constant R_SLT: std_logic_vector(5 downto 0) := "101010";
	constant R_SNE: std_logic_vector(5 downto 0) := "101001";
	constant R_SRA: std_logic_vector(5 downto 0) := "000111";
	constant R_SRL: std_logic_vector(5 downto 0) := "000110";
	constant R_SUB: std_logic_vector(5 downto 0) := "100010";
	constant R_XOR: std_logic_vector(5 downto 0) := "100110";
	
-- tipo I
	constant I_ADDI: std_logic_vector(5 downto 0) := "001000";
	constant I_ANDI: std_logic_vector(5 downto 0) := "001100";
	constant I_BEQZ: std_logic_vector(5 downto 0) := "000100";
	constant I_BNEZ: std_logic_vector(5 downto 0) := "000101";
	constant I_JALR: std_logic_vector(5 downto 0) := "010011";
	constant I_JR: std_logic_vector(5 downto 0) := "010010";
	constant I_LHI: std_logic_vector(5 downto 0) := "001111";
	constant I_LW: std_logic_vector(5 downto 0) := "100011";
	constant I_SEQI: std_logic_vector(5 downto 0) := "011000";
	constant I_SLEI: std_logic_vector(5 downto 0) := "011100";
	constant I_SLLI: std_logic_vector(5 downto 0) := "010100";
	constant I_SLTI: std_logic_vector(5 downto 0) := "011010";
	constant I_SNEI: std_logic_vector(5 downto 0) := "011001";
	constant I_SRAI: std_logic_vector(5 downto 0) := "010111";
	constant I_SRLI: std_logic_vector(5 downto 0) := "010110";
	constant I_SUBI: std_logic_vector(5 downto 0) := "001010";
	constant I_SW: std_logic_vector(5 downto 0) := "101011";
	constant I_XORI: std_logic_vector(5 downto 0) := "001110";
	
-- tipo J
	constant J_J: std_logic_vector(5 downto 0) := "000010";
	constant J_JAL: std_logic_vector(5 downto 0) := "000011";

-- tipo IF
	constant IF_LF: std_logic_vector(5 downto 0) := "100110";	
	constant IF_SF: std_logic_vector(5 downto 0) := "101110";	

-- tipo F
	
-- Le istruzioni aritmetiche di tipo F hanno il codice operativo alto sempre uguale a
-- 0x04 e il codice operativo basso che specifica l'operazione.
	constant F_ADDF: std_logic_vector(5 downto 0) := "000000";
	constant F_SUBF: std_logic_vector(5 downto 0) := "000001";	
	constant F_MULT: std_logic_vector(5 downto 0) := "001110";
	constant F_DIVF: std_logic_vector(5 downto 0) := "000011";	

end Global;


