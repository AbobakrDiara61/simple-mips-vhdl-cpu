library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ALU is
    Generic (
        Bit_Size : integer := 4
    );
    Port(
        A, B    : in STD_LOGIC_VECTOR ( Bit_Size-1 downto 0 );
        Opcode : in STD_LOGIC_VECTOR ( 3 downto 0 );
        Y   : out STD_LOGIC_VECTOR ( Bit_Size-1 downto 0 );
        ZF, SF, CF, OF : out STD_LOGIC
    );
end ALU;

architecture Behavioral of ALU is
    signal temp_result : STD_LOGIC_VECTOR ( Bit_Size downto 0 );
begin

process(A, B, Opcode)
begin
    temp_result <= (others => '0');

    case Opcode is

        when "0000" => temp_result(Bit_Size-1 downto 0) <= not A;
        when "0001" => temp_result(Bit_Size-1 downto 0) <= not B;
        when "0010" => temp_result(Bit_Size-1 downto 0) <= A and B;
        when "0011" => temp_result(Bit_Size-1 downto 0) <= A or B;
        when "0100" => temp_result(Bit_Size-1 downto 0) <= not (A and B);
        when "0101" => temp_result(Bit_Size-1 downto 0) <= not (A or B);
        when "0110" => temp_result(Bit_Size-1 downto 0) <= A xor B;
        when "0111" => temp_result(Bit_Size-1 downto 0) <= A xnor B;

        when "1000" =>
            temp_result(Bit_Size-1 downto 0) <= A(Bit_Size-2 downto 0) & '0';
            temp_result(Bit_Size) <= A(Bit_Size-1);

        when "1001" => 
            temp_result(Bit_Size-1 downto 0) <= '0' & A(Bit_Size-1 downto 1);
            temp_result(Bit_Size) <= A(0);

        when "1010" =>
            temp_result(Bit_Size-1 downto 0) <= A(Bit_Size-2 downto 0) & A(Bit_Size-1);

        when "1011" =>
            temp_result(Bit_Size-1 downto 0) <= A(0) & A(Bit_Size-1 downto 1);

        when "1100" =>
            temp_result(Bit_Size-1 downto 0) <= A - 1;

        when "1101" =>
            temp_result(Bit_Size-1 downto 0) <= B - 1;

        when "1110" =>
            temp_result <= ('0' & A) + ('0' & B);

        when others =>
            temp_result <= ('0' & A) - ('0' & B);

    end case;
end process;

Y <= temp_result(Bit_Size-1 downto 0);
ZF <= '1' when temp_result(Bit_Size-1 downto 0) = (others => '0') else '0';
SF <= temp_result(Bit_Size-1);
CF <= temp_result(Bit_Size);
OF <= (A(Bit_Size-1) xor B(Bit_Size-1)) xor temp_result(Bit_Size-1);

endBehavioral;