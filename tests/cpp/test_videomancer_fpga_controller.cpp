// Videomancer SDK - Unit Tests for videomancer_fpga_controller.hpp
// Copyright (C) 2025 LZX Industries LLC
// SPDX-License-Identifier: GPL-3.0-only

#include <lzx/videomancer/videomancer_fpga_controller.hpp>
#include <iostream>
#include <cassert>
#include <cstring>
#include <vector>

using namespace lzx;

// Mock FPGA SPI interface for testing
class mock_videomancer_fpga : public videomancer_fpga {
private:
    struct spi_transaction {
        std::vector<uint8_t> tx_data;
        bool cs_asserted;
    };
    
    std::vector<spi_transaction> transactions_;
    bool cs_state_;
    
public:
    mock_videomancer_fpga() : cs_state_(false) {}
    
    size_t transfer_spi(const uint8_t* tx_buffer, uint8_t* rx_buffer, size_t size) override {
        spi_transaction trans;
        trans.tx_data.assign(tx_buffer, tx_buffer + size);
        trans.cs_asserted = cs_state_;
        transactions_.push_back(trans);
        
        // Mock successful transfer
        if (rx_buffer) {
            memset(rx_buffer, 0, size);
        }
        
        return size;
    }
    
    void assert_chip_select_spi(bool assert) override {
        cs_state_ = assert;
    }
    
    // Test helper methods
    size_t transaction_count() const {
        return transactions_.size();
    }
    
    const spi_transaction& get_transaction(size_t index) const {
        return transactions_[index];
    }
    
    void clear_transactions() {
        transactions_.clear();
    }
    
    // Decode a 16-bit SPI frame
    struct decoded_frame {
        bool is_write;
        uint8_t address;
        uint16_t data;
    };
    
    decoded_frame decode_last_frame() const {
        if (transactions_.empty()) {
            return {false, 0, 0};
        }
        
        const auto& trans = transactions_.back();
        if (trans.tx_data.size() != 2) {
            return {false, 0, 0};
        }
        
        uint16_t frame = (static_cast<uint16_t>(trans.tx_data[0]) << 8) | trans.tx_data[1];
        
        decoded_frame result;
        result.is_write = ((frame & 0x8000) == 0);
        result.address = (frame >> 10) & 0x1F;
        result.data = frame & 0x3FF;
        
        return result;
    }
};

// Test controller initialization
bool test_controller_init() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    // Shadow registers should be initialized to zero
    if (controller.get_rotary_pot_1() != 0 ||
        controller.get_rotary_pot_2() != 0 ||
        controller.get_toggle_switches() != 0) {
        std::cerr << "FAILED: Controller init test - shadow registers not zeroed" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Controller initialization test" << std::endl;
    return true;
}

// Test setting rotary potentiometer
bool test_set_rotary_pot() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    // Set pot 1 to value 512
    bool success = controller.set_rotary_pot_1(512);
    
    if (!success) {
        std::cerr << "FAILED: Set rotary pot test - write failed" << std::endl;
        return false;
    }
    
    // Verify SPI transaction occurred
    if (fpga.transaction_count() != 1) {
        std::cerr << "FAILED: Set rotary pot test - no SPI transaction" << std::endl;
        return false;
    }
    
    // Decode and verify frame
    auto frame = fpga.decode_last_frame();
    if (!frame.is_write || frame.address != 0 || frame.data != 512) {
        std::cerr << "FAILED: Set rotary pot test - incorrect frame" << std::endl;
        return false;
    }
    
    // Verify shadow register updated
    if (controller.get_rotary_pot_1() != 512) {
        std::cerr << "FAILED: Set rotary pot test - shadow register not updated" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Set rotary potentiometer test" << std::endl;
    return true;
}

// Test value masking (10-bit limit)
bool test_value_masking() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    // Try to set value > 1023 (should be masked to 10 bits)
    controller.set_rotary_pot_1(0xFFFF);
    
    auto frame = fpga.decode_last_frame();
    if (frame.data != 0x3FF) {  // Should be masked to 1023
        std::cerr << "FAILED: Value masking test - data not masked to 10 bits" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Value masking test" << std::endl;
    return true;
}

// Test toggle switches
bool test_toggle_switches() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    // Set switch 7 on
    controller.set_toggle_switch_7(true);
    
    auto frame = fpga.decode_last_frame();
    if (frame.address != 6 || frame.data != 0x01) {
        std::cerr << "FAILED: Toggle switch test - incorrect frame" << std::endl;
        return false;
    }
    
    // Set switch 8 on (should combine with switch 7)
    controller.set_toggle_switch_8(true);
    
    frame = fpga.decode_last_frame();
    if (frame.data != 0x03) {  // Bits 0 and 1 set
        std::cerr << "FAILED: Toggle switch test - switches not combined" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Toggle switches test" << std::endl;
    return true;
}

// Test video timing setting
bool test_video_timing() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    // Set to 1080i50
    controller.set_video_timing(videomancer_abi_v1_0::video_timing_id::_1080i50);
    
    auto frame = fpga.decode_last_frame();
    if (frame.address != 8 || frame.data != 0x1) {
        std::cerr << "FAILED: Video timing test - incorrect frame" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Video timing test" << std::endl;
    return true;
}

// Test bulk update
bool test_bulk_update() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    uint16_t pots[6] = {100, 200, 300, 400, 500, 600};
    bool success = controller.set_all_rotary_pots(pots);
    
    if (!success) {
        std::cerr << "FAILED: Bulk update test - write failed" << std::endl;
        return false;
    }
    
    // Should have 6 transactions
    if (fpga.transaction_count() != 6) {
        std::cerr << "FAILED: Bulk update test - wrong transaction count" << std::endl;
        return false;
    }
    
    // Verify shadow registers
    if (controller.get_rotary_pot_3() != 300 ||
        controller.get_rotary_pot_6() != 600) {
        std::cerr << "FAILED: Bulk update test - shadow registers incorrect" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Bulk update test" << std::endl;
    return true;
}

// Test write optimization (no write if value unchanged)
bool test_write_optimization() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    // Set value
    controller.set_rotary_pot_1(512);
    size_t count1 = fpga.transaction_count();
    
    // Set same value again
    controller.set_rotary_pot_1(512);
    size_t count2 = fpga.transaction_count();
    
    // Should not have generated new transaction
    if (count2 != count1) {
        std::cerr << "FAILED: Write optimization test - unnecessary write occurred" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Write optimization test" << std::endl;
    return true;
}

// Test shadow register reset
bool test_shadow_reset() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    // Set some values
    controller.set_rotary_pot_1(500);
    controller.set_toggle_switches(0x1F);
    
    // Reset shadow registers
    controller.reset_shadow_registers();
    
    // Verify all reset to zero
    if (controller.get_rotary_pot_1() != 0 ||
        controller.get_toggle_switches() != 0) {
        std::cerr << "FAILED: Shadow reset test - registers not zeroed" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Shadow register reset test" << std::endl;
    return true;
}

// Test individual toggle switch read
bool test_toggle_switch_read() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    // Set switches 7 and 9
    controller.set_toggle_switches(0x05);  // Bits 0 and 2
    
    // Read individual switches
    if (!controller.get_toggle_switch(7) ||
        controller.get_toggle_switch(8) ||
        !controller.get_toggle_switch(9)) {
        std::cerr << "FAILED: Toggle switch read test - incorrect states" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Toggle switch read test" << std::endl;
    return true;
}

// Test SPI frame format
bool test_spi_frame_format() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    // Write address 3, data 0x2AA (binary: 10 1010 1010)
    controller.set_rotary_pot_4(0x2AA);
    
    const auto& trans = fpga.get_transaction(0);
    
    // Frame should be: [0][00011][1010101010] = 0x0EAA
    uint16_t expected = 0x0EAA;
    uint16_t actual = (static_cast<uint16_t>(trans.tx_data[0]) << 8) | trans.tx_data[1];
    
    if (actual != expected) {
        std::cerr << "FAILED: SPI frame format test - expected 0x" << std::hex << expected 
                  << " got 0x" << actual << std::dec << std::endl;
        return false;
    }
    
    std::cout << "PASSED: SPI frame format test" << std::endl;
    return true;
}

// Test chip select assertions
bool test_chip_select() {
    mock_videomancer_fpga fpga;
    videomancer_fpga_controller controller(fpga);
    
    controller.set_rotary_pot_1(100);
    
    const auto& trans = fpga.get_transaction(0);
    
    // CS should be asserted during transaction
    if (!trans.cs_asserted) {
        std::cerr << "FAILED: Chip select test - CS not asserted" << std::endl;
        return false;
    }
    
    std::cout << "PASSED: Chip select test" << std::endl;
    return true;
}

// Main test runner
int main() {
    std::cout << "======================================================" << std::endl;
    std::cout << "Videomancer videomancer_fpga_controller.hpp Tests" << std::endl;
    std::cout << "======================================================" << std::endl;
    std::cout << std::endl;
    
    int passed = 0;
    int total = 0;
    
    #define RUN_TEST(test_func) \
        do { \
            total++; \
            if (test_func()) { \
                passed++; \
            } \
        } while(0)
    
    RUN_TEST(test_controller_init);
    RUN_TEST(test_set_rotary_pot);
    RUN_TEST(test_value_masking);
    RUN_TEST(test_toggle_switches);
    RUN_TEST(test_video_timing);
    RUN_TEST(test_bulk_update);
    RUN_TEST(test_write_optimization);
    RUN_TEST(test_shadow_reset);
    RUN_TEST(test_toggle_switch_read);
    RUN_TEST(test_spi_frame_format);
    RUN_TEST(test_chip_select);
    
    std::cout << std::endl;
    std::cout << "======================================================" << std::endl;
    std::cout << "Results: " << passed << "/" << total << " tests passed" << std::endl;
    std::cout << "======================================================" << std::endl;
    
    return (passed == total) ? 0 : 1;
}
