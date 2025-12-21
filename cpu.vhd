LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

ENTITY cpu IS
  GENERIC (
    Bit_Size : INTEGER := 5;
    pc_size : INTEGER := 31
  );
  PORT (
    i_reset : IN STD_LOGIC;
    i_clock : IN STD_LOGIC;
    kit_clk : IN STD_LOGIC;

    seven_segments : OUT STD_LOGIC_VECTOR (6 DOWNTO 0);
    anode : OUT STD_LOGIC_VECTOR (1 DOWNTO 0);

    destnation_register : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0) := x"00"
  );
END cpu;

ARCHITECTURE behavioral OF cpu IS
  -- signal section
  SIGNAL SF, ZF, CF : STD_LOGIC := '0';
  SIGNAL pc_signal : STD_LOGIC_VECTOR(Bit_Size - 1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL accumulator_1 : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"00";
  SIGNAL accumulator_2 : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"00";
  -- Seven Segment signals
  SIGNAL refresh_counter : unsigned(16 DOWNTO 0) := (OTHERS => '0');
  SIGNAL mux_sel : STD_LOGIC := '0';
  SIGNAL bcd_digit : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
  SIGNAL tens_digit : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
  SIGNAL ones_digit : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

  -- computer system registers
  TYPE Registers IS ARRAY (0 TO 7) OF STD_LOGIC_VECTOR(7 DOWNTO 0);
  SIGNAL R : Registers := (
    0 => "00000101", -- 5
    1 => "00001000", -- 8
    2 => "00001100", -- 12
    3 => "00000110", -- 6
    4 => "00010000", -- 16
    5 => "00100100", -- 36
    6 => "00001001", -- 9
    7 => "00000100" -- 4
  );

  -- Define ROM
  TYPE ROM_Type IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
  SIGNAL ROM : ROM_Type := (
    -- Instruction 0: R1 <- NSH (R1) which prints 8
    -- NSH is opcode 0000, shift_code 000, src1=R1, src2=don't care, dest=R1
    -- Format: opcode(4) shift_code(3) src1(3) src2(3) dest(3)
    0 => "0000000001000001", -- R1 <- NSH(R1) 

    -- Instruction 1: R1 <- R0 + R1
    -- ADD is opcode 0001, ALU code 000, src1=R0, src2=R1, dest=R1
    1 => "0001000000001001", -- R1 <- R0 + R1

    -- Instruction 2: if R1(13) > R1(8) then branch to address 3
    -- Branch if greater than is opcode 1111, target address=00011
    2 => "1111000000000011", -- Branch if R0 > R1 to addr 00011

    -- Instruction 3: R1 <- ZERO (R1)
    -- ZERO is opcode 0000, shift_code 001, src1=R1, src2=don't care, dest=R1
    3 => "0000001001010001", -- R1 <- ZERO(R1)

    -- Instruction 4: if ZF=1 then branch to address 7
    -- Branch LZ is opcode 1101, target address=00111
    4 => "1101000000000111", -- Branch if ZF=1 to addr 00111

    -- Instruction 5: R2 <- SHR(R5)
    -- SUB is opcode 0000, Shift code 101, src1=R5, src2=don't care, dest=R2
    5 => "0000101101000010",

    -- Instruction 6: LAD without Condition Address 10
    --  Opcode: 1010 addr 01010
    6 => "1010000000001010",

    -- Instruction 7: R3 <- R7 * R3
    -- MUL is opcode 0001, ALU code 010, src1=R7, src2=R3, dest=R3
    7 => "0001010111011011", -- R3 <- R7 * R3

    -- Instruction 8: R1 <- R5 / R7
    -- DIV is opcode 0001, ALU code 011, src1=R5, src2=R7, dest=R1
    8 => "0001011101111001", -- R1 <- R5 / R7

    -- Instruction 9: if R1(9) > R7(4) then branch
    -- Branch if greater than is opcode 1111, target address=00000
    -- Need to specify target address - let's use addr 5 (00101)
    9 => "1111000000000101", -- Branch if R5 > R7 to addr 0101

    10 => x"15D8", -- R0 <- R7 * R3
    -- 11 => "0001100000111010",
    11 => x"183A", -- R2 <- R0 AND R7
    -- 12 => "0000110101000101", 
    12 => x"0D45", -- R5 <- ROR(R5)
    -- 13 => "0010000000000010", -- M[010] <- R5
    13 => x"2002", -- M[010] <- R5
    14 => "0011000000110000", -- Load from M[R0], M[R6]

    15 => x"0000",
    16 => x"0000",
    17 => x"0000",
    18 => x"0000",
    19 => x"0000",
    20 => x"0000",
    21 => x"0000",
    22 => x"0000",
    23 => x"0000",
    24 => x"0000",
    25 => x"0000",
    26 => x"0000",
    27 => x"0000",
    28 => x"0000",
    29 => x"0000",
    30 => x"0000",
    31 => x"0000"
  );

BEGIN
  PROCESS (i_reset, i_clock)
    VARIABLE pc_register : STD_LOGIC_VECTOR(Bit_Size - 1 DOWNTO 0);
    VARIABLE instruction_register : STD_LOGIC_VECTOR(15 DOWNTO 0) := x"0000";
    VARIABLE temp_result : STD_LOGIC_VECTOR(8 DOWNTO 0);
    VARIABLE temp_mul : STD_LOGIC_VECTOR(15 DOWNTO 0);
    VARIABLE src_reg1_addr : STD_LOGIC_VECTOR(2 DOWNTO 0);
    VARIABLE src_reg2_addr : STD_LOGIC_VECTOR(2 DOWNTO 0);
    VARIABLE dest_reg_addr : STD_LOGIC_VECTOR(2 DOWNTO 0);
    VARIABLE branch_target : STD_LOGIC_VECTOR(4 DOWNTO 0);
    VARIABLE next_addr : STD_LOGIC := '1';
    VARIABLE op_code : STD_LOGIC_VECTOR(3 DOWNTO 0);
    VARIABLE AC : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"00";
    VARIABLE MQ : STD_LOGIC_VECTOR(7 DOWNTO 0) := x"00";
    VARIABLE shift_code : STD_LOGIC_VECTOR(2 DOWNTO 0);
    VARIABLE memory_rw : STD_LOGIC := '0';

    VARIABLE store_addr : STD_LOGIC_VECTOR(2 DOWNTO 0);
  BEGIN
    IF i_reset = '0' THEN
      -- reset
      accumulator_1 <= x"00";
      accumulator_2 <= x"00";
      pc_signal <= (OTHERS => '0');
      ZF <= '0';
      SF <= '0';
      CF <= '0';
      destnation_register <= x"00";
      R <= (
        0 => "00000101", -- 5
        1 => "00001000", -- 8
        2 => "00001100", -- 12
        3 => "00000110", -- 6
        4 => "00010000", -- 16
        5 => "00100100", -- 36
        6 => "00001001", -- 9
        7 => "00000100" -- 4
        );
    ELSIF NOT(rising_edge(i_clock)) THEN
      -- Update PC
      pc_register := pc_signal;
      -- Fetch instruction
      instruction_register := ROM(to_integer(unsigned(pc_register)));

      -- Extract info from IR 
      op_code := instruction_register(15 DOWNTO 12);
      shift_code := instruction_register(11 DOWNTO 9);
      src_reg1_addr := instruction_register(8 DOWNTO 6); -- first source register
      src_reg2_addr := instruction_register(5 DOWNTO 3); -- second source register
      dest_reg_addr := instruction_register(2 DOWNTO 0); -- destination register
      branch_target := instruction_register(4 DOWNTO 0);
      next_addr := '1';
      AC := accumulator_1;
      MQ := accumulator_2;

      CASE op_code IS

          ----------------------------------------------------------------

        WHEN "0000" => -- shift unit
          AC := R(to_integer(unsigned(src_reg1_addr)));
          CASE shift_code IS
            WHEN "000" => -- NSH
              AC := AC;

            WHEN "001" => -- ZERO
              AC := (OTHERS => '0');
              ZF <= '1';

            WHEN "010" => -- SHL
              CF <= AC(7);
              AC := STD_LOGIC_VECTOR(shift_left(unsigned(AC), 1));
            WHEN "011" => -- ROL
              AC := AC(6 DOWNTO 0) & AC(7);

            WHEN "100" => -- RLC
              AC := AC(6 DOWNTO 0) & CF;
              SF <= AC(7);

            WHEN "101" => -- SHR
              CF <= AC(0);
              AC := STD_LOGIC_VECTOR(shift_right(unsigned(AC), 1));

            WHEN "110" => -- ROR
              AC := AC(0) & AC(7 DOWNTO 1);

            WHEN "111" => -- RRC
              AC := CF & AC(7 DOWNTO 1);

            WHEN OTHERS =>
              NULL;
          END CASE;
          IF AC = "00000000" THEN
            ZF <= '1';
          ELSE
            ZF <= '0';
          END IF;
          SF <= AC(7);
          destnation_register <= AC;
          R(to_integer(unsigned(dest_reg_addr))) <= AC;
          accumulator_1 <= AC;
          accumulator_2 <= MQ;
          ----------------------------------------------------------------
        WHEN "0001" => -- ALU operations

          AC := R(to_integer(unsigned(src_reg1_addr)));
          MQ := R(to_integer(unsigned(src_reg2_addr)));
          CASE instruction_register(11 DOWNTO 9) IS
            WHEN "000" => -- AC + MQ
              temp_result := STD_LOGIC_VECTOR(('0' & unsigned(AC)) + ('0' & unsigned(MQ)));
              AC := temp_result(7 DOWNTO 0);
              CF <= temp_result(8);
              IF AC = "00000000" THEN
                ZF <= '1';
              ELSE
                ZF <= '0';
              END IF;
              SF <= AC(7);

            WHEN "001" => -- AC - MQ
              temp_result := STD_LOGIC_VECTOR(('0' & unsigned(AC)) - ('0' & unsigned(MQ)));
              AC := temp_result(7 DOWNTO 0);
              CF <= temp_result(8);
              IF AC = "00000000" THEN
                ZF <= '1';
              ELSE
                ZF <= '0';
              END IF;
              SF <= AC(7);

            WHEN "010" => -- AC * MQ
              temp_mul := STD_LOGIC_VECTOR(unsigned(AC) * unsigned(MQ));
              AC := temp_mul(7 DOWNTO 0);
              CF <= '0';
              IF AC = "00000000" THEN
                ZF <= '1';
              ELSE
                ZF <= '0';
              END IF;
              SF <= AC(7);

            WHEN "011" => -- AC / MQ
              IF MQ /= "00000000" THEN
                AC := STD_LOGIC_VECTOR(unsigned(AC) / unsigned(MQ));
              ELSE
                AC := (OTHERS => '0');
              END IF;
              CF <= '0';
              IF AC = "00000000" THEN
                ZF <= '1';
              ELSE
                ZF <= '0';
              END IF;
              SF <= AC(7);

            WHEN "100" => -- AND
              AC := AC AND MQ;
              CF <= '0';
              IF AC = "00000000" THEN
                ZF <= '1';
              ELSE
                ZF <= '0';
              END IF;
              SF <= AC(7);

            WHEN "101" => -- OR
              AC := AC OR MQ;
              CF <= '0';
              IF AC = "00000000" THEN
                ZF <= '1';
              ELSE
                ZF <= '0';
              END IF;
              SF <= AC(7);

            WHEN "110" => -- XOR
              AC := AC XOR MQ;
              CF <= '0';
              IF AC = "00000000" THEN
                ZF <= '1';
              ELSE
                ZF <= '0';
              END IF;
              SF <= AC(7);

            WHEN "111" => -- NOT
              AC := NOT AC;
              CF <= '0';
              IF AC = "00000000" THEN
                ZF <= '1';
              ELSE
                ZF <= '0';
              END IF;
              SF <= AC(7);
              MQ := x"00";
            WHEN OTHERS =>
              NULL;
          END CASE;
          destnation_register <= AC;
          R(to_integer(unsigned(dest_reg_addr))) <= AC;
          accumulator_1 <= AC;
          accumulator_2 <= MQ;
          ----------------------------------------------------------------
          -- Other opcodes (Store, Toggle, Increment/Decrement, etc.)
        WHEN "0010" => -- Store to memory M[addr] ← $rs
          store_addr := instruction_register(2 DOWNTO 0);
          R(to_integer(unsigned(store_addr))) <= AC;

        WHEN "0011" => -- Load From Memory $rs ← M[addr] $rd ← M[addr]
          accumulator_1 <= R(to_integer(unsigned(src_reg1_addr)));
          accumulator_2 <= R(to_integer(unsigned(src_reg2_addr)));
          destnation_register <= R(to_integer(unsigned(src_reg1_addr)));
        WHEN "0100" =>
          AC := NOT AC;
          CF <= '0';
          IF AC = "00000000" THEN
            ZF <= '1';
          ELSE
            ZF <= '0';
          END IF;
          SF <= AC(7);
          destnation_register <= AC;

        WHEN "0101" =>
          MQ := NOT MQ;
          CF <= '0';
          IF MQ = "00000000" THEN
            ZF <= '1';
          ELSE
            ZF <= '0';
          END IF;
          SF <= MQ(7);
          destnation_register <= MQ;

        WHEN "0110" => -- Branch if Lower than
          AC := NOT MQ;
          CF <= '0';
          IF AC = "00000000" THEN
            ZF <= '1';
          ELSE
            ZF <= '0';
          END IF;
          SF <= AC(7);
          destnation_register <= AC;

        WHEN "0111" => -- Mirror AC
          AC := AC(0) & AC(1) & AC(2) & AC(3) & AC(4) & AC(5) & AC(6) & AC(7);
          IF AC = "00000000" THEN
            ZF <= '1';
          ELSE
            ZF <= '0';
          END IF;
          SF <= AC(7);
          destnation_register <= AC;

        WHEN "1000" => -- Mirror MQ
          MQ := MQ(0) & MQ(1) & MQ(2) & MQ(3) & MQ(4) & MQ(5) & MQ(6) & MQ(7);
          CF <= '0';
          IF MQ = "00000000" THEN
            ZF <= '1';
          ELSE
            ZF <= '0';
          END IF;
          SF <= MQ(7);
          destnation_register <= MQ;

        WHEN "1001" =>
          IF (accumulator_1 < accumulator_2) THEN
            pc_register := branch_target;
            next_addr := '0';
          END IF;

        WHEN "1010" => -- Branch LAD
          pc_register := branch_target;
          next_addr := '0';

        WHEN "1011" => -- Branch LS
          IF (SF = '1') THEN
            pc_register := branch_target;
            next_addr := '0';
          END IF;

        WHEN "1100" => -- Branch LC
          IF (CF = '1') THEN
            pc_register := branch_target;
            next_addr := '0';
          END IF;

        WHEN "1101" => -- Branch LZ
          IF (ZF = '1') THEN
            pc_register := branch_target;
            next_addr := '0';
          END IF;

        WHEN "1110" =>
          IF (accumulator_1 = accumulator_2) THEN -- Branch if equal
            pc_register := branch_target;
            next_addr := '0';
          END IF;
        WHEN "1111" => -- Branch if greater than
          IF (accumulator_1 > accumulator_2) THEN
            pc_register := branch_target;
            next_addr := '0';
          END IF;
        WHEN OTHERS =>
          NULL;

      END CASE;

      IF next_addr /= '0' THEN
        IF unsigned(pc_register) = pc_size THEN
          pc_register := "00000";
        ELSE
          pc_register := STD_LOGIC_VECTOR(unsigned(pc_register) + 1);
        END IF;
      END IF;
      pc_signal <= pc_register;
    END IF;
  END PROCESS;

  PROCESS (kit_clk)

    VARIABLE num_int : INTEGER RANGE 0 TO 99;
    VARIABLE tens : INTEGER RANGE 0 TO 9;
    VARIABLE ones : INTEGER RANGE 0 TO 9;

  BEGIN
    IF NOT(rising_edge(kit_clk)) THEN
      num_int := to_integer(unsigned(destnation_register));
      tens := num_int / 10; -- Get tens digit
      ones := num_int MOD 10; -- Get ones digit

      tens_digit <= STD_LOGIC_VECTOR(to_unsigned(tens, 4));
      ones_digit <= STD_LOGIC_VECTOR(to_unsigned(ones, 4));
    END IF;
  END PROCESS;
  -- Clk 50kHz refresh rate
  PROCESS (kit_clk)
  BEGIN
    IF NOT(rising_edge(kit_clk)) THEN
      refresh_counter <= refresh_counter + 1;
    END IF;
  END PROCESS;

  -- Use a MSB for switching between 7 segments
  mux_sel <= refresh_counter (16); -- 729Hz refresh rate

  -- Multiplex between tens and ones digits
  PROCESS (mux_sel, tens_digit, ones_digit)
  BEGIN
    IF mux_sel = '0' THEN
      bcd_digit <= tens_digit; -- Display tens digit
      anode <= "01"; -- Enable first display, disable second
    ELSE
      bcd_digit <= ones_digit; -- Display ones digit
      anode <= "10"; -- Enable second display, disable first
    END IF;
  END PROCESS;

  -- 7-segment decoder
  PROCESS (bcd_digit)
  BEGIN
    CASE bcd_digit IS
      WHEN "0000" => seven_segments <= "1000000"; -- 0
      WHEN "0001" => seven_segments <= "1111001"; -- 1
      WHEN "0010" => seven_segments <= "0100100"; -- 2
      WHEN "0011" => seven_segments <= "0110000"; -- 3
      WHEN "0100" => seven_segments <= "0011001"; -- 4
      WHEN "0101" => seven_segments <= "0010010"; -- 5
      WHEN "0110" => seven_segments <= "0000010"; -- 6
      WHEN "0111" => seven_segments <= "1111000"; -- 7
      WHEN "1000" => seven_segments <= "0000000"; -- 8
      WHEN "1001" => seven_segments <= "0010000"; -- 9

      WHEN OTHERS => seven_segments <= "1111111"; -- null
    END CASE;
  END PROCESS;
END behavioral;