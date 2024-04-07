/*
BSD 2-Clause License

Copyright (c) 2018, Ethereum Name Service
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// Repo: ensdomains/buffer
// Commit: https://github.com/ensdomains/buffer/blob/f942d329b73206bf11bf699178f7bc7136163c8f/contracts/Buffer.sol

// SPDX-License-Identifier: BSD-2-Clause
pragma solidity ^0.8.4;

/**
 * @dev A library for working with mutable byte buffers in Solidity.
 *
 * Byte buffers are mutable and expandable, and provide a variety of primitives
 * for appending to them. At any time you can fetch a bytes object containing the
 * current contents of the buffer. The bytes object should not be stored between
 * operations, as it may change due to resizing of the buffer.
 */
library Buffer {
    /**
     * @dev Represents a mutable buffer. Buffers have a current value (buf) and
     *      a capacity. The capacity may be longer than the current value, in
     *      which case it can be extended without the need to allocate more memory.
     */
    struct buffer {
        bytes buf;
        uint capacity;
    }

    /**
     * @dev Initializes a buffer with an initial capacity.
     * @param buf The buffer to initialize.
     * @param capacity The number of bytes of space to allocate the buffer.
     * @return The buffer, for chaining.
     */
    function init(buffer memory buf, uint capacity) internal pure returns (buffer memory) {
        if (capacity % 32 != 0) {
            capacity += 32 - (capacity % 32);
        }
        // Allocate space for the buffer data
        buf.capacity = capacity;
        assembly {
            let ptr := mload(0x40)
            mstore(buf, ptr)
            mstore(ptr, 0)
            let fpm := add(32, add(ptr, capacity))
            if lt(fpm, ptr) {
                revert(0, 0)
            }
            mstore(0x40, fpm)
        }
        return buf;
    }

    /**
     * @dev Initializes a new buffer from an existing bytes object.
     *      Changes to the buffer may mutate the original value.
     * @param b The bytes object to initialize the buffer with.
     * @return A new buffer.
     */
    function fromBytes(bytes memory b) internal pure returns (buffer memory) {
        buffer memory buf;
        buf.buf = b;
        buf.capacity = b.length;
        return buf;
    }

    function resize(buffer memory buf, uint capacity) private pure {
        bytes memory oldbuf = buf.buf;
        init(buf, capacity);
        append(buf, oldbuf);
    }

    /**
     * @dev Sets buffer length to 0.
     * @param buf The buffer to truncate.
     * @return The original buffer, for chaining..
     */
    function truncate(buffer memory buf) internal pure returns (buffer memory) {
        assembly {
            let bufptr := mload(buf)
            mstore(bufptr, 0)
        }
        return buf;
    }

    /**
     * @dev Appends len bytes of a byte string to a buffer. Resizes if doing so would exceed
     *      the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @param len The number of bytes to copy.
     * @return The original buffer, for chaining.
     */
    function append(
        buffer memory buf,
        bytes memory data,
        uint len
    ) internal pure returns (buffer memory) {
        require(len <= data.length);

        uint off = buf.buf.length;
        uint newCapacity = off + len;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        uint dest;
        uint src;
        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Length of existing buffer data
            let buflen := mload(bufptr)
            // Start address = buffer address + offset + sizeof(buffer length)
            dest := add(add(bufptr, 32), off)
            // Update buffer length if we're extending it
            if gt(newCapacity, buflen) {
                mstore(bufptr, newCapacity)
            }
            src := add(data, 32)
        }

        // Copy word-length chunks while possible
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        unchecked {
            uint mask = (256 ** (32 - len)) - 1;
            assembly {
                let srcpart := and(mload(src), not(mask))
                let destpart := and(mload(dest), mask)
                mstore(dest, or(destpart, srcpart))
            }
        }

        return buf;
    }

    /**
     * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
     *      the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer, for chaining.
     */
    function append(buffer memory buf, bytes memory data) internal pure returns (buffer memory) {
        return append(buf, data, data.length);
    }

    /**
     * @dev Appends a byte to the buffer. Resizes if doing so would exceed the
     *      capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer, for chaining.
     */
    function appendUint8(buffer memory buf, uint8 data) internal pure returns (buffer memory) {
        uint off = buf.buf.length;
        uint offPlusOne = off + 1;
        if (off >= buf.capacity) {
            resize(buf, offPlusOne * 2);
        }

        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Address = buffer address + sizeof(buffer length) + off
            let dest := add(add(bufptr, off), 32)
            mstore8(dest, data)
            // Update buffer length if we extended it
            if gt(offPlusOne, mload(bufptr)) {
                mstore(bufptr, offPlusOne)
            }
        }

        return buf;
    }

    /**
     * @dev Appends len bytes of bytes32 to a buffer. Resizes if doing so would
     *      exceed the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @param len The number of bytes to write (left-aligned).
     * @return The original buffer, for chaining.
     */
    function append(
        buffer memory buf,
        bytes32 data,
        uint len
    ) private pure returns (buffer memory) {
        uint off = buf.buf.length;
        uint newCapacity = len + off;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        unchecked {
            uint mask = (256 ** len) - 1;
            // Right-align data
            data = data >> (8 * (32 - len));
            assembly {
                // Memory address of the buffer data
                let bufptr := mload(buf)
                // Address = buffer address + sizeof(buffer length) + newCapacity
                let dest := add(bufptr, newCapacity)
                mstore(dest, or(and(mload(dest), not(mask)), data))
                // Update buffer length if we extended it
                if gt(newCapacity, mload(bufptr)) {
                    mstore(bufptr, newCapacity)
                }
            }
        }
        return buf;
    }

    /**
     * @dev Appends a bytes20 to the buffer. Resizes if doing so would exceed
     *      the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer, for chhaining.
     */
    function appendBytes20(buffer memory buf, bytes20 data) internal pure returns (buffer memory) {
        return append(buf, bytes32(data), 20);
    }

    /**
     * @dev Appends a bytes32 to the buffer. Resizes if doing so would exceed
     *      the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @return The original buffer, for chaining.
     */
    function appendBytes32(buffer memory buf, bytes32 data) internal pure returns (buffer memory) {
        return append(buf, data, 32);
    }

    /**
     * @dev Appends a byte to the end of the buffer. Resizes if doing so would
     *      exceed the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @param len The number of bytes to write (right-aligned).
     * @return The original buffer.
     */
    function appendInt(
        buffer memory buf,
        uint data,
        uint len
    ) internal pure returns (buffer memory) {
        uint off = buf.buf.length;
        uint newCapacity = len + off;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        uint mask = (256 ** len) - 1;
        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Address = buffer address + sizeof(buffer length) + newCapacity
            let dest := add(bufptr, newCapacity)
            mstore(dest, or(and(mload(dest), not(mask)), data))
            // Update buffer length if we extended it
            if gt(newCapacity, mload(bufptr)) {
                mstore(bufptr, newCapacity)
            }
        }
        return buf;
    }
}

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

/// @title Library containing miscellaneous functions used on the project
/// @author Zondax AG
library Misc {
    uint64 constant DAG_CBOR_CODEC = 0x71;
    uint64 constant CBOR_CODEC = 0x51;
    uint64 constant NONE_CODEC = 0x00;

    // Code taken from Openzeppelin repo
    // Link: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/0320a718e8e07b1d932f5acb8ad9cec9d9eed99b/contracts/utils/math/SignedMath.sol#L37-L42
    /// @notice get the abs from a signed number
    /// @param n number to get abs from
    /// @return unsigned number
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}
/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

// 	MajUnsignedInt = 0
// 	MajSignedInt   = 1
// 	MajByteString  = 2
// 	MajTextString  = 3
// 	MajArray       = 4
// 	MajMap         = 5
// 	MajTag         = 6
// 	MajOther       = 7

uint8 constant MajUnsignedInt = 0;
uint8 constant MajSignedInt = 1;
uint8 constant MajByteString = 2;
uint8 constant MajTextString = 3;
uint8 constant MajArray = 4;
uint8 constant MajMap = 5;
uint8 constant MajTag = 6;
uint8 constant MajOther = 7;

uint8 constant TagTypeBigNum = 2;
uint8 constant TagTypeNegativeBigNum = 3;

uint8 constant True_Type = 21;
uint8 constant False_Type = 20;

/// @notice This library is a set a functions that allows anyone to decode cbor encoded bytes
/// @dev methods in this library try to read the data type indicated from cbor encoded data stored in bytes at a specific index
/// @dev if it successes, methods will return the read value and the new index (intial index plus read bytes)
/// @author Zondax AG
library CBORDecoder {
    /// @notice check if next value on the cbor encoded data is null
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    function isNullNext(bytes memory cborData, uint byteIdx) internal pure returns (bool) {
        return cborData[byteIdx] == hex"f6";
    }

    /// @notice attempt to read a bool value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return a bool decoded from input bytes and the byte index after moving past the value
    function readBool(bytes memory cborData, uint byteIdx) internal pure returns (bool, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajOther, "invalid maj (expected MajOther)");
        assert(value == True_Type || value == False_Type);

        return (value != False_Type, byteIdx);
    }

    /// @notice attempt to read the length of a fixed array
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return length of the fixed array decoded from input bytes and the byte index after moving past the value
    function readFixedArray(
        bytes memory cborData,
        uint byteIdx
    ) internal pure returns (uint, uint) {
        uint8 maj;
        uint len;

        (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajArray, "invalid maj (expected MajArray)");

        return (len, byteIdx);
    }

    /// @notice attempt to read an arbitrary length string value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return arbitrary length string decoded from input bytes and the byte index after moving past the value
    function readString(
        bytes memory cborData,
        uint byteIdx
    ) internal pure returns (string memory, uint) {
        uint8 maj;
        uint len;

        (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajTextString, "invalid maj (expected MajTextString)");

        uint max_len = byteIdx + len;
        bytes memory slice = new bytes(len);
        uint slice_index = 0;
        for (uint256 i = byteIdx; i < max_len; i++) {
            slice[slice_index] = cborData[i];
            slice_index++;
        }

        return (string(slice), byteIdx + len);
    }

    /// @notice attempt to read an arbitrary byte string value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return arbitrary byte string decoded from input bytes and the byte index after moving past the value
    function readBytes(
        bytes memory cborData,
        uint byteIdx
    ) internal pure returns (bytes memory, uint) {
        uint8 maj;
        uint len;

        (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(
            maj == MajTag || maj == MajByteString,
            "invalid maj (expected MajTag or MajByteString)"
        );

        if (maj == MajTag) {
            (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
            assert(maj == MajByteString);
        }

        uint max_len = byteIdx + len;
        bytes memory slice = new bytes(len);
        uint slice_index = 0;
        for (uint256 i = byteIdx; i < max_len; i++) {
            slice[slice_index] = cborData[i];
            slice_index++;
        }

        return (slice, byteIdx + len);
    }

    /// @notice attempt to read a bytes32 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return a bytes32 decoded from input bytes and the byte index after moving past the value
    function readBytes32(
        bytes memory cborData,
        uint byteIdx
    ) internal pure returns (bytes32, uint) {
        uint8 maj;
        uint len;

        (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajByteString, "invalid maj (expected MajByteString)");

        uint max_len = byteIdx + len;
        bytes memory slice = new bytes(32);
        uint slice_index = 32 - len;
        for (uint256 i = byteIdx; i < max_len; i++) {
            slice[slice_index] = cborData[i];
            slice_index++;
        }

        return (bytes32(slice), byteIdx + len);
    }

    /// @notice attempt to read a uint256 value encoded per cbor specification
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an uint256 decoded from input bytes and the byte index after moving past the value
    function readUInt256(
        bytes memory cborData,
        uint byteIdx
    ) internal pure returns (uint256, uint) {
        uint8 maj;
        uint256 value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(
            maj == MajTag || maj == MajUnsignedInt,
            "invalid maj (expected MajTag or MajUnsignedInt)"
        );

        if (maj == MajTag) {
            require(value == TagTypeBigNum, "invalid tag (expected TagTypeBigNum)");

            uint len;
            (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
            require(maj == MajByteString, "invalid maj (expected MajByteString)");

            require(cborData.length >= byteIdx + len, "slicing out of range");
            assembly {
                value := mload(add(cborData, add(len, byteIdx)))
            }

            return (value, byteIdx + len);
        }

        return (value, byteIdx);
    }

    /// @notice attempt to read a int256 value encoded per cbor specification
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an int256 decoded from input bytes and the byte index after moving past the value
    function readInt256(bytes memory cborData, uint byteIdx) internal pure returns (int256, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(
            maj == MajTag || maj == MajSignedInt,
            "invalid maj (expected MajTag or MajSignedInt)"
        );

        if (maj == MajTag) {
            assert(value == TagTypeNegativeBigNum);

            uint len;
            (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
            require(maj == MajByteString, "invalid maj (expected MajByteString)");

            require(cborData.length >= byteIdx + len, "slicing out of range");
            assembly {
                value := mload(add(cborData, add(len, byteIdx)))
            }

            return (int256(value), byteIdx + len);
        }

        return (int256(value), byteIdx);
    }

    /// @notice attempt to read a uint64 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an uint64 decoded from input bytes and the byte index after moving past the value
    function readUInt64(bytes memory cborData, uint byteIdx) internal pure returns (uint64, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajUnsignedInt, "invalid maj (expected MajUnsignedInt)");

        return (uint64(value), byteIdx);
    }

    /// @notice attempt to read a uint32 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an uint32 decoded from input bytes and the byte index after moving past the value
    function readUInt32(bytes memory cborData, uint byteIdx) internal pure returns (uint32, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajUnsignedInt, "invalid maj (expected MajUnsignedInt)");

        return (uint32(value), byteIdx);
    }

    /// @notice attempt to read a uint16 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an uint16 decoded from input bytes and the byte index after moving past the value
    function readUInt16(bytes memory cborData, uint byteIdx) internal pure returns (uint16, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajUnsignedInt, "invalid maj (expected MajUnsignedInt)");

        return (uint16(value), byteIdx);
    }

    /// @notice attempt to read a uint8 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an uint8 decoded from input bytes and the byte index after moving past the value
    function readUInt8(bytes memory cborData, uint byteIdx) internal pure returns (uint8, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajUnsignedInt, "invalid maj (expected MajUnsignedInt)");

        return (uint8(value), byteIdx);
    }

    /// @notice attempt to read a int64 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an int64 decoded from input bytes and the byte index after moving past the value
    function readInt64(bytes memory cborData, uint byteIdx) internal pure returns (int64, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(
            maj == MajSignedInt || maj == MajUnsignedInt,
            "invalid maj (expected MajSignedInt or MajUnsignedInt)"
        );

        return (int64(uint64(value)), byteIdx);
    }

    /// @notice attempt to read a int32 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an int32 decoded from input bytes and the byte index after moving past the value
    function readInt32(bytes memory cborData, uint byteIdx) internal pure returns (int32, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(
            maj == MajSignedInt || maj == MajUnsignedInt,
            "invalid maj (expected MajSignedInt or MajUnsignedInt)"
        );

        return (int32(uint32(value)), byteIdx);
    }

    /// @notice attempt to read a int16 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an int16 decoded from input bytes and the byte index after moving past the value
    function readInt16(bytes memory cborData, uint byteIdx) internal pure returns (int16, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(
            maj == MajSignedInt || maj == MajUnsignedInt,
            "invalid maj (expected MajSignedInt or MajUnsignedInt)"
        );

        return (int16(uint16(value)), byteIdx);
    }

    /// @notice attempt to read a int8 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an int8 decoded from input bytes and the byte index after moving past the value
    function readInt8(bytes memory cborData, uint byteIdx) internal pure returns (int8, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(
            maj == MajSignedInt || maj == MajUnsignedInt,
            "invalid maj (expected MajSignedInt or MajUnsignedInt)"
        );

        return (int8(uint8(value)), byteIdx);
    }

    /// @notice slice uint8 from bytes starting at a given index
    /// @param bs bytes to slice from
    /// @param start current position to slice from bytes
    /// @return uint8 sliced from bytes
    function sliceUInt8(bytes memory bs, uint start) internal pure returns (uint8) {
        require(bs.length >= start + 1, "slicing out of range");
        return uint8(bs[start]);
    }

    /// @notice slice uint16 from bytes starting at a given index
    /// @param bs bytes to slice from
    /// @param start current position to slice from bytes
    /// @return uint16 sliced from bytes
    function sliceUInt16(bytes memory bs, uint start) internal pure returns (uint16) {
        require(bs.length >= start + 2, "slicing out of range");
        bytes2 x;
        assembly {
            x := mload(add(bs, add(0x20, start)))
        }
        return uint16(x);
    }

    /// @notice slice uint32 from bytes starting at a given index
    /// @param bs bytes to slice from
    /// @param start current position to slice from bytes
    /// @return uint32 sliced from bytes
    function sliceUInt32(bytes memory bs, uint start) internal pure returns (uint32) {
        require(bs.length >= start + 4, "slicing out of range");
        bytes4 x;
        assembly {
            x := mload(add(bs, add(0x20, start)))
        }
        return uint32(x);
    }

    /// @notice slice uint64 from bytes starting at a given index
    /// @param bs bytes to slice from
    /// @param start current position to slice from bytes
    /// @return uint64 sliced from bytes
    function sliceUInt64(bytes memory bs, uint start) internal pure returns (uint64) {
        require(bs.length >= start + 8, "slicing out of range");
        bytes8 x;
        assembly {
            x := mload(add(bs, add(0x20, start)))
        }
        return uint64(x);
    }

    /// @notice Parse cbor header for major type and extra info.
    /// @param cbor cbor encoded bytes to parse from
    /// @param byteIndex current position to read on the cbor encoded bytes
    /// @return major type, extra info and the byte index after moving past header bytes
    function parseCborHeader(
        bytes memory cbor,
        uint byteIndex
    ) internal pure returns (uint8, uint64, uint) {
        uint8 first = sliceUInt8(cbor, byteIndex);
        byteIndex += 1;
        uint8 maj = (first & 0xe0) >> 5;
        uint8 low = first & 0x1f;
        // We don't handle CBOR headers with extra > 27, i.e. no indefinite lengths
        require(low < 28, "cannot handle headers with extra > 27");

        // extra is lower bits
        if (low < 24) {
            return (maj, low, byteIndex);
        }

        // extra in next byte
        if (low == 24) {
            uint8 next = sliceUInt8(cbor, byteIndex);
            byteIndex += 1;
            require(next >= 24, "invalid cbor"); // otherwise this is invalid cbor
            return (maj, next, byteIndex);
        }

        // extra in next 2 bytes
        if (low == 25) {
            uint16 extra16 = sliceUInt16(cbor, byteIndex);
            byteIndex += 2;
            return (maj, extra16, byteIndex);
        }

        // extra in next 4 bytes
        if (low == 26) {
            uint32 extra32 = sliceUInt32(cbor, byteIndex);
            byteIndex += 4;
            return (maj, extra32, byteIndex);
        }

        // extra in next 8 bytes
        assert(low == 27);
        uint64 extra64 = sliceUInt64(cbor, byteIndex);
        byteIndex += 8;
        return (maj, extra64, byteIndex);
    }
}

/*
MIT License

Copyright (c) 2018 SmartContract ChainLink, Ltd.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

// Repo: smartcontractkit/solidity-cborutils
// Commit: https://github.com/smartcontractkit/solidity-cborutils/blob/85c4254acd81d855c953090111931ca811853bec/contracts/CBOR.sol

/**
 * @dev A library for populating CBOR encoded payload in Solidity.
 *
 * https://datatracker.ietf.org/doc/html/rfc7049
 *
 * The library offers various write* and start* methods to encode values of different types.
 * The resulted buffer can be obtained with data() method.
 * Encoding of primitive types is staightforward, whereas encoding of sequences can result
 * in an invalid CBOR if start/write/end flow is violated.
 * For the purpose of gas saving, the library does not verify start/write/end flow internally,
 * except for nested start/end pairs.
 */

library CBOR {
    using Buffer for Buffer.buffer;

    struct CBORBuffer {
        Buffer.buffer buf;
        uint256 depth;
    }

    uint8 private constant MAJOR_TYPE_INT = 0;
    uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
    uint8 private constant MAJOR_TYPE_BYTES = 2;
    uint8 private constant MAJOR_TYPE_STRING = 3;
    uint8 private constant MAJOR_TYPE_ARRAY = 4;
    uint8 private constant MAJOR_TYPE_MAP = 5;
    uint8 private constant MAJOR_TYPE_TAG = 6;
    uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;

    uint8 private constant TAG_TYPE_BIGNUM = 2;
    uint8 private constant TAG_TYPE_NEGATIVE_BIGNUM = 3;

    uint8 private constant CBOR_FALSE = 20;
    uint8 private constant CBOR_TRUE = 21;
    uint8 private constant CBOR_NULL = 22;
    uint8 private constant CBOR_UNDEFINED = 23;

    function create(uint256 capacity) internal pure returns (CBORBuffer memory cbor) {
        Buffer.init(cbor.buf, capacity);
        cbor.depth = 0;
        return cbor;
    }

    function data(CBORBuffer memory buf) internal pure returns (bytes memory) {
        require(buf.depth == 0, "Invalid CBOR");
        return buf.buf.buf;
    }

    function writeUInt256(CBORBuffer memory buf, uint256 value) internal pure {
        buf.buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_BIGNUM));
        writeBytes(buf, abi.encode(value));
    }

    function writeInt256(CBORBuffer memory buf, int256 value) internal pure {
        if (value < 0) {
            buf.buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_NEGATIVE_BIGNUM));
            writeBytes(buf, abi.encode(uint256(-1 - value)));
        } else {
            writeUInt256(buf, uint256(value));
        }
    }

    function writeUInt64(CBORBuffer memory buf, uint64 value) internal pure {
        writeFixedNumeric(buf, MAJOR_TYPE_INT, value);
    }

    function writeInt64(CBORBuffer memory buf, int64 value) internal pure {
        if (value >= 0) {
            writeFixedNumeric(buf, MAJOR_TYPE_INT, uint64(value));
        } else {
            writeFixedNumeric(buf, MAJOR_TYPE_NEGATIVE_INT, uint64(-1 - value));
        }
    }

    function writeBytes(CBORBuffer memory buf, bytes memory value) internal pure {
        writeFixedNumeric(buf, MAJOR_TYPE_BYTES, uint64(value.length));
        buf.buf.append(value);
    }

    function writeString(CBORBuffer memory buf, string memory value) internal pure {
        writeFixedNumeric(buf, MAJOR_TYPE_STRING, uint64(bytes(value).length));
        buf.buf.append(bytes(value));
    }

    function writeBool(CBORBuffer memory buf, bool value) internal pure {
        writeContentFree(buf, value ? CBOR_TRUE : CBOR_FALSE);
    }

    function writeNull(CBORBuffer memory buf) internal pure {
        writeContentFree(buf, CBOR_NULL);
    }

    function writeUndefined(CBORBuffer memory buf) internal pure {
        writeContentFree(buf, CBOR_UNDEFINED);
    }

    function startArray(CBORBuffer memory buf) internal pure {
        writeIndefiniteLengthType(buf, MAJOR_TYPE_ARRAY);
        buf.depth += 1;
    }

    function startFixedArray(CBORBuffer memory buf, uint64 length) internal pure {
        writeDefiniteLengthType(buf, MAJOR_TYPE_ARRAY, length);
    }

    function startMap(CBORBuffer memory buf) internal pure {
        writeIndefiniteLengthType(buf, MAJOR_TYPE_MAP);
        buf.depth += 1;
    }

    function startFixedMap(CBORBuffer memory buf, uint64 length) internal pure {
        writeDefiniteLengthType(buf, MAJOR_TYPE_MAP, length);
    }

    function endSequence(CBORBuffer memory buf) internal pure {
        writeIndefiniteLengthType(buf, MAJOR_TYPE_CONTENT_FREE);
        buf.depth -= 1;
    }

    function writeKVString(
        CBORBuffer memory buf,
        string memory key,
        string memory value
    ) internal pure {
        writeString(buf, key);
        writeString(buf, value);
    }

    function writeKVBytes(
        CBORBuffer memory buf,
        string memory key,
        bytes memory value
    ) internal pure {
        writeString(buf, key);
        writeBytes(buf, value);
    }

    function writeKVUInt256(CBORBuffer memory buf, string memory key, uint256 value) internal pure {
        writeString(buf, key);
        writeUInt256(buf, value);
    }

    function writeKVInt256(CBORBuffer memory buf, string memory key, int256 value) internal pure {
        writeString(buf, key);
        writeInt256(buf, value);
    }

    function writeKVUInt64(CBORBuffer memory buf, string memory key, uint64 value) internal pure {
        writeString(buf, key);
        writeUInt64(buf, value);
    }

    function writeKVInt64(CBORBuffer memory buf, string memory key, int64 value) internal pure {
        writeString(buf, key);
        writeInt64(buf, value);
    }

    function writeKVBool(CBORBuffer memory buf, string memory key, bool value) internal pure {
        writeString(buf, key);
        writeBool(buf, value);
    }

    function writeKVNull(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        writeNull(buf);
    }

    function writeKVUndefined(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        writeUndefined(buf);
    }

    function writeKVMap(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        startMap(buf);
    }

    function writeKVArray(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        startArray(buf);
    }

    function writeFixedNumeric(CBORBuffer memory buf, uint8 major, uint64 value) private pure {
        if (value <= 23) {
            buf.buf.appendUint8(uint8((major << 5) | value));
        } else if (value <= 0xFF) {
            buf.buf.appendUint8(uint8((major << 5) | 24));
            buf.buf.appendInt(value, 1);
        } else if (value <= 0xFFFF) {
            buf.buf.appendUint8(uint8((major << 5) | 25));
            buf.buf.appendInt(value, 2);
        } else if (value <= 0xFFFFFFFF) {
            buf.buf.appendUint8(uint8((major << 5) | 26));
            buf.buf.appendInt(value, 4);
        } else {
            buf.buf.appendUint8(uint8((major << 5) | 27));
            buf.buf.appendInt(value, 8);
        }
    }

    function writeIndefiniteLengthType(CBORBuffer memory buf, uint8 major) private pure {
        buf.buf.appendUint8(uint8((major << 5) | 31));
    }

    function writeDefiniteLengthType(
        CBORBuffer memory buf,
        uint8 major,
        uint64 length
    ) private pure {
        writeFixedNumeric(buf, major, length);
    }

    function writeContentFree(CBORBuffer memory buf, uint8 value) private pure {
        buf.buf.appendUint8(uint8((MAJOR_TYPE_CONTENT_FREE << 5) | value));
    }
}

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// CID
bytes7 constant CID_COMMP_HEADER = hex"0181e203922020";
uint8 constant CID_COMMP_HEADER_LENGTH = 7;

// Proofs
uint8 constant MERKLE_TREE_NODE_SIZE = 32;
bytes32 constant TRUNCATOR = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff3f;
uint64 constant BYTES_IN_INT = 8;
uint64 constant CHECKSUM_SIZE = 16;
uint64 constant ENTRY_SIZE = uint64(MERKLE_TREE_NODE_SIZE) + 2 * BYTES_IN_INT + CHECKSUM_SIZE;
uint64 constant BYTES_IN_DATA_SEGMENT_ENTRY = 2 * MERKLE_TREE_NODE_SIZE;

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

/// @title Filecoin actors' common types for Solidity.
/// @author Zondax AG
library CommonTypes {
    uint constant UniversalReceiverHookMethodNum = 3726118371;

    /// @param idx index for the failure in batch
    /// @param code failure code
    struct FailCode {
        uint32 idx;
        uint32 code;
    }

    /// @param success_count total successes in batch
    /// @param fail_codes list of failures code and index for each failure in batch
    struct BatchReturn {
        uint32 success_count;
        FailCode[] fail_codes;
    }

    /// @param type_ asset type
    /// @param payload payload corresponding to asset type
    struct UniversalReceiverParams {
        uint32 type_;
        bytes payload;
    }

    /// @param val contains the actual arbitrary number written as binary
    /// @param neg indicates if val is negative or not
    struct BigInt {
        bytes val;
        bool neg;
    }

    /// @param data filecoin address in bytes format
    struct FilAddress {
        bytes data;
    }

    /// @param data cid in bytes format
    struct Cid {
        bytes data;
    }

    type FilActorId is uint64;
}

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

/// @title This library is a set of functions meant to handle CBOR serialization and deserialization for BigInt type
/// @author Zondax AG
library BigIntCBOR {
    /// @notice serialize BigInt instance to bytes
    /// @param num BigInt instance to serialize
    /// @return serialized BigInt as bytes
    function serializeBigInt(CommonTypes.BigInt memory num) internal pure returns (bytes memory) {
        bytes memory raw = new bytes(num.val.length + 1);

        raw[0] = num.neg == true ? bytes1(0x01) : bytes1(0x00);

        uint index = 1;
        for (uint i = 0; i < num.val.length; i++) {
            raw[index] = num.val[i];
            index++;
        }

        return raw;
    }

    /// @notice deserialize big int (encoded as bytes) to BigInt instance
    /// @param raw as bytes to parse
    /// @return parsed BigInt instance
    function deserializeBigInt(bytes memory raw) internal pure returns (CommonTypes.BigInt memory) {
        if (raw.length == 0) {
            return CommonTypes.BigInt(hex"00", false);
        }

        bytes memory val = new bytes(raw.length - 1);
        bool neg = false;

        if (raw[0] == 0x01) {
            neg = true;
        }

        for (uint i = 1; i < raw.length; i++) {
            val[i - 1] = raw[i];
        }

        return CommonTypes.BigInt(val, neg);
    }
}

/// @title Filecoin market actor types for Solidity.
/// @author Zondax AG
library MarketTypes {
    CommonTypes.FilActorId constant ActorID = CommonTypes.FilActorId.wrap(5);
    uint constant AddBalanceMethodNum = 822473126;
    uint constant WithdrawBalanceMethodNum = 2280458852;
    uint constant GetBalanceMethodNum = 726108461;
    uint constant GetDealDataCommitmentMethodNum = 1157985802;
    uint constant GetDealClientMethodNum = 128053329;
    uint constant GetDealProviderMethodNum = 935081690;
    uint constant GetDealLabelMethodNum = 46363526;
    uint constant GetDealTermMethodNum = 163777312;
    uint constant GetDealEpochPriceMethodNum = 4287162428;
    uint constant GetDealClientCollateralMethodNum = 200567895;
    uint constant GetDealProviderCollateralMethodNum = 2986712137;
    uint constant GetDealVerifiedMethodNum = 2627389465;
    uint constant GetDealActivationMethodNum = 2567238399;
    uint constant PublishStorageDealsMethodNum = 2236929350;

    /// @param provider_or_client the address of provider or client.
    /// @param tokenAmount the token amount to withdraw.
    struct WithdrawBalanceParams {
        CommonTypes.FilAddress provider_or_client;
        CommonTypes.BigInt tokenAmount;
    }

    /// @param balance the escrow balance for this address.
    /// @param locked the escrow locked amount for this address.
    struct GetBalanceReturn {
        CommonTypes.BigInt balance;
        CommonTypes.BigInt locked;
    }

    /// @param data the data commitment of this deal.
    /// @param size the size of this deal.
    struct GetDealDataCommitmentReturn {
        bytes data;
        uint64 size;
    }

    /// @param start the chain epoch to start the deal.
    /// @param endthe chain epoch to end the deal.
    struct GetDealTermReturn {
        int64 start;
        int64 end;
    }

    /// @param activated Epoch at which the deal was activated, or -1.
    /// @param terminated Epoch at which the deal was terminated abnormally, or -1.
    struct GetDealActivationReturn {
        int64 activated;
        int64 terminated;
    }

    /// @param deals list of deal proposals signed by a client
    struct PublishStorageDealsParams {
        ClientDealProposal[] deals;
    }

    /// @param ids returned storage deal IDs.
    /// @param valid_deals represent all the valid deals.
    struct PublishStorageDealsReturn {
        CommonTypes.FilActorId[] ids;
        bytes valid_deals;
    }

    /// @param piece_cid PieceCID.
    /// @param piece_size the size of the piece.
    /// @param verified_deal if the deal is verified or not.
    /// @param client the address of the storage client.
    /// @param provider the address of the storage provider.
    /// @param label any label that client choose for the deal.
    /// @param start_epoch the chain epoch to start the deal.
    /// @param end_epoch the chain epoch to end the deal.
    /// @param storage_price_per_epoch the token amount to pay to provider per epoch.
    /// @param provider_collateral the token amount as collateral paid by the provider.
    /// @param client_collateral the token amount as collateral paid by the client.
    struct DealProposal {
        CommonTypes.Cid piece_cid;
        uint64 piece_size;
        bool verified_deal;
        CommonTypes.FilAddress client;
        CommonTypes.FilAddress provider;
        string label;
        int64 start_epoch;
        int64 end_epoch;
        CommonTypes.BigInt storage_price_per_epoch;
        CommonTypes.BigInt provider_collateral;
        CommonTypes.BigInt client_collateral;
    }

    /// @param proposal Proposal
    /// @param client_signature the signature signed by the client.
    struct ClientDealProposal {
        DealProposal proposal;
        bytes client_signature;
    }
}

// Uncomment this line to use console.log
// import "hardhat/console.sol";

library Cid {
    // cidToPieceCommitment converts a CID to a piece commitment.
    function cidToPieceCommitment(bytes memory _cb) internal pure returns (bytes32) {
        require(
            _cb.length == CID_COMMP_HEADER_LENGTH + MERKLE_TREE_NODE_SIZE,
            "wrong length of CID"
        );
        require(
            keccak256(abi.encodePacked(_cb[0], _cb[1], _cb[2], _cb[3], _cb[4], _cb[5], _cb[6])) ==
                keccak256(abi.encodePacked(CID_COMMP_HEADER)),
            "wrong content of CID header"
        );
        bytes32 res;
        assembly {
            res := mload(add(add(_cb, CID_COMMP_HEADER_LENGTH), MERKLE_TREE_NODE_SIZE))
        }
        return res;
    }

    // pieceCommitmentToCid converts a piece commitment to a CID.
    function pieceCommitmentToCid(bytes32 _commp) internal pure returns (bytes memory) {
        bytes memory cb = abi.encodePacked(CID_COMMP_HEADER, _commp);
        return cb;
    }
}

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// Behavioral Interface for an aggregator oracle
interface IAggregatorOracle {
    struct Deal {
        // A unique identifier for the deal.
        uint64 dealId;
        // The miner that is storing the data for the deal.
        uint64 minerId;
    }

    // Emitted when a new request is submitted with an ID and content identifier (CID).
    event SubmitAggregatorRequest(uint256 indexed id, bytes cid);

    // Emitted when a new request is submitted with an ID, content identifier (CID), and RaaS parameters
    event SubmitAggregatorRequestWithRaaS(
        uint256 indexed id,
        bytes cid,
        uint256 _replication_target,
        uint256 _repair_threshold,
        uint256 _renew_threshold
    );

    // Emitted when a request is completed, providing the request ID and deal ID.
    event CompleteAggregatorRequest(uint256 indexed id, uint64 indexed dealId);

    // Function that submits a new request to the oracle
    function submit(bytes memory _cid) external returns (uint256);

    // Function to submit a new file to the aggregator, specifing the raas parameters
    function submitRaaS(
        bytes memory _cid,
        uint256 _replication_target,
        uint256 _repair_threshold,
        uint256 _renew_threshold
    ) external returns (uint256);

    // Callback function that is called by the aggregator
    function complete(
        uint256 _id,
        uint64 _dealId,
        uint64 _minerId,
        InclusionProof memory _proof,
        InclusionVerifierData memory _verifierData
    ) external returns (InclusionAuxData memory);

    function getAllCIDs() external view returns (bytes[] memory);

    // Get all deal IDs for a specified cid
    function getAllDeals(bytes memory _cid) external view returns (Deal[] memory);

    // getActiveDeals should return all the _cid's active dealIds
    function getActiveDeals(bytes memory _cid) external returns (Deal[] memory);

    // getExpiringDeals should return all the deals' dealIds if they are expiring within `epochs`
    function getExpiringDeals(bytes memory _cid, uint64 epochs) external returns (Deal[] memory);
}

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// ProofData is a Merkle proof
struct ProofData {
    uint64 index;
    bytes32[] path;
}

// InclusionPoof is produced by the aggregator (or possibly by the SP)
struct InclusionProof {
    // ProofSubtree is proof of inclusion of the client's data segment in the data aggregator's Merkle tree (includes position information)
    // I.e. a proof that the root node of the subtree containing all the nodes (leafs) of a data segment is contained in CommDA
    ProofData proofSubtree;
    // ProofIndex is a proof that an entry for the user's data is contained in the index of the aggregator's deal.
    // I.e. a proof that the data segment index constructed from the root of the user's data segment subtree is contained in the index of the deal tree.
    ProofData proofIndex;
}

// InclusionVerifierData is the information required for verification of the proof and is sourced
// from the client.
struct InclusionVerifierData {
    // Piece Commitment CID to client's data
    bytes commPc;
    // SizePc is size of client's data
    uint64 sizePc;
}

// InclusionAuxData is required for verification of the proof and needs to be cross-checked with the chain state
struct InclusionAuxData {
    // Piece Commitment CID to aggregator's deal
    bytes commPa;
    // SizePa is padded size of aggregator's deal
    uint64 sizePa;
}

// SegmentDesc is a description of a data segment.
struct SegmentDesc {
    bytes32 commDs;
    uint64 offset;
    uint64 size;
    bytes16 checksum;
}

struct Fr32 {
    bytes32 value;
}

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

/// @title This library is a set of functions meant to handle CBOR serialization and deserialization for general data types on the filecoin network.
/// @author Zondax AG
library FilecoinCBOR {
    using Buffer for Buffer.buffer;
    using CBOR for CBOR.CBORBuffer;
    using CBORDecoder for *;
    using BigIntCBOR for *;

    uint8 private constant MAJOR_TYPE_TAG = 6;
    uint8 private constant TAG_TYPE_CID_CODE = 42;
    uint8 private constant PAYLOAD_LEN_8_BITS = 24;

    /// @notice write CID into a cbor buffer
    /// @dev the cbor major will be 6 (type tag) and the tag type is 42, as per filecoin definition
    /// @param buf buffer containing the actual cbor serialization process
    /// @param value cid data to serialize as cbor
    function writeCid(CBOR.CBORBuffer memory buf, bytes memory value) internal pure {
        buf.buf.appendUint8(uint8(((MAJOR_TYPE_TAG << 5) | PAYLOAD_LEN_8_BITS)));
        buf.buf.appendUint8(TAG_TYPE_CID_CODE);
        buf.writeBytes(value);
    }

    /// @notice serialize filecoin address to cbor encoded
    /// @param addr filecoin address to serialize
    /// @return cbor serialized data as bytes
    function serializeAddress(
        CommonTypes.FilAddress memory addr
    ) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.writeBytes(addr.data);

        return buf.data();
    }

    /// @notice serialize a BigInt value wrapped in a cbor fixed array.
    /// @param value BigInt to serialize as cbor inside an
    /// @return cbor serialized data as bytes
    function serializeArrayBigInt(
        CommonTypes.BigInt memory value
    ) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(1);
        buf.writeBytes(value.serializeBigInt());

        return buf.data();
    }

    /// @notice serialize a FilAddress value wrapped in a cbor fixed array.
    /// @param addr FilAddress to serialize as cbor inside an
    /// @return cbor serialized data as bytes
    function serializeArrayFilAddress(
        CommonTypes.FilAddress memory addr
    ) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(1);
        buf.writeBytes(addr.data);

        return buf.data();
    }

    /// @notice deserialize a FilAddress wrapped on a cbor fixed array coming from a actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of FilAddress created based on parsed data
    function deserializeArrayFilAddress(
        bytes memory rawResp
    ) internal pure returns (CommonTypes.FilAddress memory ret) {
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        (ret.data, byteIdx) = rawResp.readBytes(byteIdx);

        return ret;
    }

    /// @notice deserialize a BigInt wrapped on a cbor fixed array coming from a actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of BigInt created based on parsed data
    function deserializeArrayBigInt(
        bytes memory rawResp
    ) internal pure returns (CommonTypes.BigInt memory) {
        uint byteIdx = 0;
        uint len;
        bytes memory tmp;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 1);

        (tmp, byteIdx) = rawResp.readBytes(byteIdx);
        return tmp.deserializeBigInt();
    }

    /// @notice serialize UniversalReceiverParams struct to cbor in order to pass as arguments to an actor
    /// @param params UniversalReceiverParams to serialize as cbor
    /// @return cbor serialized data as bytes
    function serializeUniversalReceiverParams(
        CommonTypes.UniversalReceiverParams memory params
    ) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(2);
        buf.writeUInt64(params.type_);
        buf.writeBytes(params.payload);

        return buf.data();
    }

    /// @notice deserialize UniversalReceiverParams cbor to struct when receiving a message
    /// @param rawResp cbor encoded response
    /// @return ret new instance of UniversalReceiverParams created based on parsed data
    function deserializeUniversalReceiverParams(
        bytes memory rawResp
    ) internal pure returns (CommonTypes.UniversalReceiverParams memory ret) {
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        require(len == 2, "Wrong numbers of parameters (should find 2)");

        (ret.type_, byteIdx) = rawResp.readUInt32(byteIdx);
        (ret.payload, byteIdx) = rawResp.readBytes(byteIdx);
    }

    /// @notice attempt to read a FilActorId value
    /// @param rawResp cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return a FilActorId decoded from input bytes and the byte index after moving past the value
    function readFilActorId(
        bytes memory rawResp,
        uint byteIdx
    ) internal pure returns (CommonTypes.FilActorId, uint) {
        uint64 tmp = 0;

        (tmp, byteIdx) = rawResp.readUInt64(byteIdx);
        return (CommonTypes.FilActorId.wrap(tmp), byteIdx);
    }

    /// @notice write FilActorId into a cbor buffer
    /// @dev FilActorId is just wrapping a uint64
    /// @param buf buffer containing the actual cbor serialization process
    /// @param id FilActorId to serialize as cbor
    function writeFilActorId(CBOR.CBORBuffer memory buf, CommonTypes.FilActorId id) internal pure {
        buf.writeUInt64(CommonTypes.FilActorId.unwrap(id));
    }
}

/// @title This library is a set of functions meant to handle CBOR parameters serialization and return values deserialization for Market actor exported methods.
/// @author Zondax AG
library MarketCBOR {
    using CBOR for CBOR.CBORBuffer;
    using CBORDecoder for bytes;
    using BigIntCBOR for *;
    using FilecoinCBOR for *;

    /// @notice serialize WithdrawBalanceParams struct to cbor in order to pass as arguments to the market actor
    /// @param params WithdrawBalanceParams to serialize as cbor
    /// @return response cbor serialized data as bytes
    function serializeWithdrawBalanceParams(
        MarketTypes.WithdrawBalanceParams memory params
    ) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(2);
        buf.writeBytes(params.provider_or_client.data);
        buf.writeBytes(params.tokenAmount.serializeBigInt());

        return buf.data();
    }

    /// @notice deserialize GetBalanceReturn struct from cbor encoded bytes coming from a market actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of GetBalanceReturn created based on parsed data
    function deserializeGetBalanceReturn(
        bytes memory rawResp
    ) internal pure returns (MarketTypes.GetBalanceReturn memory ret) {
        uint byteIdx = 0;
        uint len;
        bytes memory tmp;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 2);

        (tmp, byteIdx) = rawResp.readBytes(byteIdx);
        ret.balance = tmp.deserializeBigInt();

        (tmp, byteIdx) = rawResp.readBytes(byteIdx);
        ret.locked = tmp.deserializeBigInt();

        return ret;
    }

    /// @notice deserialize GetDealDataCommitmentReturn struct from cbor encoded bytes coming from a market actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of GetDealDataCommitmentReturn created based on parsed data
    function deserializeGetDealDataCommitmentReturn(
        bytes memory rawResp
    ) internal pure returns (MarketTypes.GetDealDataCommitmentReturn memory ret) {
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);

        if (len > 0) {
            (ret.data, byteIdx) = rawResp.readBytes(byteIdx);
            (ret.size, byteIdx) = rawResp.readUInt64(byteIdx);
        } else {
            ret.data = new bytes(0);
            ret.size = 0;
        }

        return ret;
    }

    /// @notice deserialize GetDealTermReturn struct from cbor encoded bytes coming from a market actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of GetDealTermReturn created based on parsed data
    function deserializeGetDealTermReturn(
        bytes memory rawResp
    ) internal pure returns (MarketTypes.GetDealTermReturn memory ret) {
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 2);

        (ret.start, byteIdx) = rawResp.readInt64(byteIdx);
        (ret.end, byteIdx) = rawResp.readInt64(byteIdx);

        return ret;
    }

    /// @notice deserialize GetDealActivationReturn struct from cbor encoded bytes coming from a market actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of GetDealActivationReturn created based on parsed data
    function deserializeGetDealActivationReturn(
        bytes memory rawResp
    ) internal pure returns (MarketTypes.GetDealActivationReturn memory ret) {
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 2);

        (ret.activated, byteIdx) = rawResp.readInt64(byteIdx);
        (ret.terminated, byteIdx) = rawResp.readInt64(byteIdx);

        return ret;
    }

    /// @notice serialize PublishStorageDealsParams struct to cbor in order to pass as arguments to the market actor
    /// @param params PublishStorageDealsParams to serialize as cbor
    /// @return cbor serialized data as bytes
    function serializePublishStorageDealsParams(
        MarketTypes.PublishStorageDealsParams memory params
    ) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(1);
        buf.startFixedArray(uint64(params.deals.length));

        for (uint64 i = 0; i < params.deals.length; i++) {
            buf.startFixedArray(2);

            buf.startFixedArray(11);

            buf.writeCid(params.deals[i].proposal.piece_cid.data);
            buf.writeUInt64(params.deals[i].proposal.piece_size);
            buf.writeBool(params.deals[i].proposal.verified_deal);
            buf.writeBytes(params.deals[i].proposal.client.data);
            buf.writeBytes(params.deals[i].proposal.provider.data);
            buf.writeString(params.deals[i].proposal.label);
            buf.writeInt64(params.deals[i].proposal.start_epoch);
            buf.writeInt64(params.deals[i].proposal.end_epoch);
            buf.writeBytes(params.deals[i].proposal.storage_price_per_epoch.serializeBigInt());
            buf.writeBytes(params.deals[i].proposal.provider_collateral.serializeBigInt());
            buf.writeBytes(params.deals[i].proposal.client_collateral.serializeBigInt());

            buf.writeBytes(params.deals[i].client_signature);
        }

        return buf.data();
    }

    /// @notice deserialize PublishStorageDealsReturn struct from cbor encoded bytes coming from a market actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of PublishStorageDealsReturn created based on parsed data
    function deserializePublishStorageDealsReturn(
        bytes memory rawResp
    ) internal pure returns (MarketTypes.PublishStorageDealsReturn memory ret) {
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 2);

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        ret.ids = new CommonTypes.FilActorId[](len);

        for (uint i = 0; i < len; i++) {
            (ret.ids[i], byteIdx) = rawResp.readFilActorId(byteIdx);
        }

        (ret.valid_deals, byteIdx) = rawResp.readBytes(byteIdx);

        return ret;
    }

    /// @notice serialize deal id (uint64) to cbor in order to pass as arguments to the market actor
    /// @param id deal id to serialize as cbor
    /// @return cbor serialized data as bytes
    function serializeDealID(uint64 id) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.writeUInt64(id);

        return buf.data();
    }
}

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

/// @title This library is a set of functions meant to handle CBOR serialization and deserialization for bytes
/// @author Zondax AG
library BytesCBOR {
    using CBOR for CBOR.CBORBuffer;
    using CBORDecoder for bytes;
    using BigIntCBOR for bytes;

    /// @notice serialize raw bytes as cbor bytes string encoded
    /// @param data raw data in bytes
    /// @return encoded cbor bytes
    function serializeBytes(bytes memory data) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.writeBytes(data);

        return buf.data();
    }

    /// @notice serialize raw address (in bytes) as cbor bytes string encoded (how an address is passed to filecoin actors)
    /// @param addr raw address in bytes
    /// @return encoded address as cbor bytes
    function serializeAddress(bytes memory addr) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.writeBytes(addr);

        return buf.data();
    }

    /// @notice encoded null value as cbor
    /// @return cbor encoded null
    function serializeNull() internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.writeNull();

        return buf.data();
    }

    /// @notice deserialize cbor encoded filecoin address to bytes
    /// @param ret cbor encoded filecoin address
    /// @return raw bytes representing a filecoin address
    function deserializeAddress(bytes memory ret) internal pure returns (bytes memory) {
        bytes memory addr;
        uint byteIdx = 0;

        (addr, byteIdx) = ret.readBytes(byteIdx);

        return addr;
    }

    /// @notice deserialize cbor encoded string
    /// @param ret cbor encoded string (in bytes)
    /// @return decoded string
    function deserializeString(bytes memory ret) internal pure returns (string memory) {
        string memory response;
        uint byteIdx = 0;

        (response, byteIdx) = ret.readString(byteIdx);

        return response;
    }

    /// @notice deserialize cbor encoded bool
    /// @param ret cbor encoded bool (in bytes)
    /// @return decoded bool
    function deserializeBool(bytes memory ret) internal pure returns (bool) {
        bool response;
        uint byteIdx = 0;

        (response, byteIdx) = ret.readBool(byteIdx);

        return response;
    }

    /// @notice deserialize cbor encoded BigInt
    /// @param ret cbor encoded BigInt (in bytes)
    /// @return decoded BigInt
    /// @dev BigInts are cbor encoded as bytes string first. That is why it unwraps the cbor encoded bytes first, and then parse the result into BigInt
    function deserializeBytesBigInt(
        bytes memory ret
    ) internal pure returns (CommonTypes.BigInt memory) {
        bytes memory tmp;
        uint byteIdx = 0;

        if (ret.length > 0) {
            (tmp, byteIdx) = ret.readBytes(byteIdx);
            if (tmp.length > 0) {
                return tmp.deserializeBigInt();
            }
        }

        return CommonTypes.BigInt(new bytes(0), false);
    }

    /// @notice deserialize cbor encoded uint64
    /// @param rawResp cbor encoded uint64 (in bytes)
    /// @return decoded uint64
    function deserializeUint64(bytes memory rawResp) internal pure returns (uint64) {
        uint byteIdx = 0;
        uint64 value;

        (value, byteIdx) = rawResp.readUInt64(byteIdx);
        return value;
    }

    /// @notice deserialize cbor encoded int64
    /// @param rawResp cbor encoded int64 (in bytes)
    /// @return decoded int64
    function deserializeInt64(bytes memory rawResp) internal pure returns (int64) {
        uint byteIdx = 0;
        int64 value;

        (value, byteIdx) = rawResp.readInt64(byteIdx);
        return value;
    }
}

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

/// @title Call actors utilities library, meant to interact with Filecoin builtin actors
/// @author Zondax AG
library Actor {
    /// @notice precompile address for the call_actor precompile
    address constant CALL_ACTOR_ADDRESS = 0xfe00000000000000000000000000000000000003;

    /// @notice precompile address for the call_actor_id precompile
    address constant CALL_ACTOR_ID = 0xfe00000000000000000000000000000000000005;

    /// @notice flag used to indicate that the call_actor or call_actor_id should perform a static_call to the desired actor
    uint64 constant READ_ONLY_FLAG = 0x00000001;

    /// @notice flag used to indicate that the call_actor or call_actor_id should perform a delegate_call to the desired actor
    uint64 constant DEFAULT_FLAG = 0x00000000;

    /// @notice the provided address is not valid
    error InvalidAddress(bytes addr);

    /// @notice the smart contract has no enough balance to transfer
    error NotEnoughBalance(uint256 balance, uint256 value);

    /// @notice the provided actor id is not valid
    error InvalidActorID(CommonTypes.FilActorId actorId);

    /// @notice an error happened trying to call the actor
    error FailToCallActor();

    /// @notice the response received is not correct. In some case no response is expected and we received one, or a response was indeed expected and we received none.
    error InvalidResponseLength();

    /// @notice the codec received is not valid
    error InvalidCodec(uint64);

    /// @notice the called actor returned an error as part of its expected behaviour
    error ActorError(int256 errorCode);

    /// @notice allows to interact with an specific actor by its address (bytes format)
    /// @param actor_address actor address (bytes format) to interact with
    /// @param method_num id of the method from the actor to call
    /// @param codec how the request data passed as argument is encoded
    /// @param raw_request encoded arguments to be passed in the call
    /// @param value tokens to be transferred to the called actor
    /// @param static_call indicates if the call will be allowed to change the actor state or not (just read the state)
    /// @return payload (in bytes) with the actual response data (without codec or response code)
    function callByAddress(
        bytes memory actor_address,
        uint256 method_num,
        uint64 codec,
        bytes memory raw_request,
        uint256 value,
        bool static_call
    ) internal returns (bytes memory) {
        if (actor_address.length < 2) {
            revert InvalidAddress(actor_address);
        }

        uint balance = address(this).balance;
        if (balance < value) {
            revert NotEnoughBalance(balance, value);
        }

        // We have to delegate-call the call-actor precompile because the call-actor precompile will
        // call the target actor on our behalf. This will _not_ delegate to the target `actor_address`.
        //
        // Specifically:
        //
        // - `static_call == false`: `CALLER (you) --(DELEGATECALL)-> CALL_ACTOR_PRECOMPILE --(CALL)-> actor_address
        // - `static_call == true`:  `CALLER (you) --(DELEGATECALL)-> CALL_ACTOR_PRECOMPILE --(STATICCALL)-> actor_address
        (bool success, bytes memory data) = address(CALL_ACTOR_ADDRESS).delegatecall(
            abi.encode(
                uint64(method_num),
                value,
                static_call ? READ_ONLY_FLAG : DEFAULT_FLAG,
                codec,
                raw_request,
                actor_address
            )
        );
        if (!success) {
            revert FailToCallActor();
        }

        return readRespData(data);
    }

    /// @notice allows to interact with an specific actor by its id (uint64)
    /// @param target actor id (uint64) to interact with
    /// @param method_num id of the method from the actor to call
    /// @param codec how the request data passed as argument is encoded
    /// @param raw_request encoded arguments to be passed in the call
    /// @param value tokens to be transferred to the called actor
    /// @param static_call indicates if the call will be allowed to change the actor state or not (just read the state)
    /// @return payload (in bytes) with the actual response data (without codec or response code)
    function callByID(
        CommonTypes.FilActorId target,
        uint256 method_num,
        uint64 codec,
        bytes memory raw_request,
        uint256 value,
        bool static_call
    ) internal returns (bytes memory) {
        uint balance = address(this).balance;
        if (balance < value) {
            revert NotEnoughBalance(balance, value);
        }

        (bool success, bytes memory data) = address(CALL_ACTOR_ID).delegatecall(
            abi.encode(
                uint64(method_num),
                value,
                static_call ? READ_ONLY_FLAG : DEFAULT_FLAG,
                codec,
                raw_request,
                target
            )
        );
        if (!success) {
            revert FailToCallActor();
        }

        return readRespData(data);
    }

    /// @notice allows to interact with an non-singleton actors by its id (uint64)
    /// @param target actor id (uint64) to interact with
    /// @param method_num id of the method from the actor to call
    /// @param codec how the request data passed as argument is encoded
    /// @param raw_request encoded arguments to be passed in the call
    /// @param value tokens to be transfered to the called actor
    /// @param static_call indicates if the call will be allowed to change the actor state or not (just read the state)
    /// @dev it requires the id to be bigger than 99, as singleton actors are smaller than that
    function callNonSingletonByID(
        CommonTypes.FilActorId target,
        uint256 method_num,
        uint64 codec,
        bytes memory raw_request,
        uint256 value,
        bool static_call
    ) internal returns (bytes memory) {
        if (CommonTypes.FilActorId.unwrap(target) < 100) {
            revert InvalidActorID(target);
        }

        return callByID(target, method_num, codec, raw_request, value, static_call);
    }

    /// @notice parse the response an actor returned
    /// @notice it will validate the return code (success) and the codec (valid one)
    /// @param raw_response raw data (bytes) the actor returned
    /// @return the actual raw data (payload, in bytes) to be parsed according to the actor and method called
    function readRespData(bytes memory raw_response) internal pure returns (bytes memory) {
        (int256 exit, uint64 return_codec, bytes memory return_value) = abi.decode(
            raw_response,
            (int256, uint64, bytes)
        );

        if (return_codec == Misc.NONE_CODEC) {
            if (return_value.length != 0) {
                revert InvalidResponseLength();
            }
        } else if (return_codec == Misc.CBOR_CODEC || return_codec == Misc.DAG_CBOR_CODEC) {
            if (return_value.length == 0) {
                revert InvalidResponseLength();
            }
        } else {
            revert InvalidCodec(return_codec);
        }

        if (exit != 0) {
            revert ActorError(exit);
        }

        return return_value;
    }
}

/// @title This library is a proxy to the singleton Storage Market actor (address: f05). Calling one of its methods will result in a cross-actor call being performed.
/// @author Zondax AG
library MarketAPI {
    using BytesCBOR for bytes;
    using MarketCBOR for *;
    using FilecoinCBOR for *;

    /// @notice Deposits the received value into the balance held in escrow.
    function addBalance(CommonTypes.FilAddress memory providerOrClient, uint256 value) internal {
        bytes memory raw_request = providerOrClient.serializeAddress();

        bytes memory data = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.AddBalanceMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            value,
            false
        );
        if (data.length != 0) {
            revert Actor.InvalidResponseLength();
        }
    }

    /// @notice Attempt to withdraw the specified amount from the balance held in escrow.
    /// @notice If less than the specified amount is available, yields the entire available balance.
    function withdrawBalance(
        MarketTypes.WithdrawBalanceParams memory params
    ) internal returns (CommonTypes.BigInt memory) {
        bytes memory raw_request = params.serializeWithdrawBalanceParams();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.WithdrawBalanceMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            false
        );

        return result.deserializeBytesBigInt();
    }

    /// @notice Return the escrow balance and locked amount for an address.
    /// @return the escrow balance and locked amount for an address.
    function getBalance(
        CommonTypes.FilAddress memory addr
    ) internal returns (MarketTypes.GetBalanceReturn memory) {
        bytes memory raw_request = addr.serializeAddress();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetBalanceMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeGetBalanceReturn();
    }

    /// @notice This will be available after the deal is published (whether or not is is activated) and up until some undefined period after it is terminated.
    /// @return the data commitment and size of a deal proposal.
    function getDealDataCommitment(
        uint64 dealID
    ) internal returns (MarketTypes.GetDealDataCommitmentReturn memory) {
        bytes memory raw_request = dealID.serializeDealID();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetDealDataCommitmentMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeGetDealDataCommitmentReturn();
    }

    /// @notice get the client of the deal proposal.
    /// @return the client of a deal proposal.
    function getDealClient(uint64 dealID) internal returns (uint64) {
        bytes memory raw_request = dealID.serializeDealID();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetDealClientMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeUint64();
    }

    /// @notice get the provider of a deal proposal.
    /// @return the provider of a deal proposal.
    function getDealProvider(uint64 dealID) internal returns (uint64) {
        bytes memory raw_request = dealID.serializeDealID();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetDealProviderMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeUint64();
    }

    /// @notice Get the label of a deal proposal.
    /// @return the label of a deal proposal.
    function getDealLabel(uint64 dealID) internal returns (string memory) {
        bytes memory raw_request = dealID.serializeDealID();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetDealLabelMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeString();
    }

    /// @notice Get the start epoch and duration(in epochs) of a deal proposal.
    /// @return the start epoch and duration (in epochs) of a deal proposal.
    function getDealTerm(uint64 dealID) internal returns (MarketTypes.GetDealTermReturn memory) {
        bytes memory raw_request = dealID.serializeDealID();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetDealTermMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeGetDealTermReturn();
    }

    /// @notice get the total price that will be paid from the client to the provider for this deal.
    /// @return the per-epoch price of a deal proposal.
    function getDealTotalPrice(uint64 dealID) internal returns (CommonTypes.BigInt memory) {
        bytes memory raw_request = dealID.serializeDealID();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetDealEpochPriceMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeBytesBigInt();
    }

    /// @notice get the client collateral requirement for a deal proposal.
    /// @return the client collateral requirement for a deal proposal.
    function getDealClientCollateral(uint64 dealID) internal returns (CommonTypes.BigInt memory) {
        bytes memory raw_request = dealID.serializeDealID();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetDealClientCollateralMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeBytesBigInt();
    }

    /// @notice get the provide collateral requirement for a deal proposal.
    /// @return the provider collateral requirement for a deal proposal.
    function getDealProviderCollateral(uint64 dealID) internal returns (CommonTypes.BigInt memory) {
        bytes memory raw_request = dealID.serializeDealID();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetDealProviderCollateralMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeBytesBigInt();
    }

    /// @notice get the verified flag for a deal proposal.
    /// @notice Note that the source of truth for verified allocations and claims is the verified registry actor.
    /// @return the verified flag for a deal proposal.
    function getDealVerified(uint64 dealID) internal returns (bool) {
        bytes memory raw_request = dealID.serializeDealID();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetDealVerifiedMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeBool();
    }

    /// @notice Fetches activation state for a deal.
    /// @notice This will be available from when the proposal is published until an undefined period after the deal finishes (either normally or by termination).
    /// @return USR_NOT_FOUND if the deal doesn't exist (yet), or EX_DEAL_EXPIRED if the deal has been removed from state.
    function getDealActivation(
        uint64 dealID
    ) internal returns (MarketTypes.GetDealActivationReturn memory) {
        bytes memory raw_request = dealID.serializeDealID();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.GetDealActivationMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            true
        );

        return result.deserializeGetDealActivationReturn();
    }

    /// @notice Publish a new set of storage deals (not yet included in a sector).
    function publishStorageDeals(
        MarketTypes.PublishStorageDealsParams memory params
    ) internal returns (MarketTypes.PublishStorageDealsReturn memory) {
        bytes memory raw_request = params.serializePublishStorageDealsParams();

        bytes memory result = Actor.callByID(
            MarketTypes.ActorID,
            MarketTypes.PublishStorageDealsMethodNum,
            Misc.CBOR_CODEC,
            raw_request,
            0,
            false
        );

        return result.deserializePublishStorageDealsReturn();
    }
}

contract Proof {
    using Cid for bytes;
    using Cid for bytes32;

    // computeExpectedAuxData computes the expected auxiliary data given an inclusion proof and the data provided by the verifier.
    function computeExpectedAuxData(
        InclusionProof memory ip,
        InclusionVerifierData memory verifierData
    ) internal pure returns (InclusionAuxData memory) {
        require(
            isPow2(uint64(verifierData.sizePc)),
            "Size of piece provided by verifier is not power of two"
        );

        bytes32 commPc = verifierData.commPc.cidToPieceCommitment();
        bytes32 assumedCommPa = computeRoot(ip.proofSubtree, commPc);

        (bool ok, uint64 assumedSizePa) = checkedMultiply(
            uint64(1) << uint64(ip.proofSubtree.path.length),
            uint64(verifierData.sizePc)
        );
        require(ok, "assumedSizePa overflow");

        uint64 dataOffset = ip.proofSubtree.index * uint64(verifierData.sizePc);
        SegmentDesc memory en = makeDataSegmentIndexEntry(
            Fr32(commPc),
            dataOffset,
            uint64(verifierData.sizePc)
        );
        bytes32 enNode = truncatedHash(serialize(en));
        bytes32 assumedCommPa2 = computeRoot(ip.proofIndex, enNode);
        require(assumedCommPa == assumedCommPa2, "aggregator's data commitments don't match");

        (bool ok2, uint64 assumedSizePa2) = checkedMultiply(
            uint64(1) << uint64(ip.proofIndex.path.length),
            BYTES_IN_DATA_SEGMENT_ENTRY
        );
        require(ok2, "assumedSizePau64 overflow");
        require(assumedSizePa == assumedSizePa2, "aggregator's data size doesn't match");

        validateIndexEntry(ip, assumedSizePa2);
        return InclusionAuxData(assumedCommPa.pieceCommitmentToCid(), assumedSizePa);
    }

    // computeExpectedAuxDataWithDeal computes the expected auxiliary data given an inclusion proof and the data provided by the verifier
    // and validates that the deal is activated and not terminated.
    function computeExpectedAuxDataWithDeal(
        uint64 dealId,
        InclusionProof memory ip,
        InclusionVerifierData memory verifierData
    ) internal returns (InclusionAuxData memory) {
        InclusionAuxData memory inclusionAuxData = computeExpectedAuxData(ip, verifierData);
        validateInclusionAuxData(dealId, inclusionAuxData);
        return inclusionAuxData;
    }

    // validateInclusionAuxData validates that the deal is activated and not terminated.
    function validateInclusionAuxData(
        uint64 dealId,
        InclusionAuxData memory inclusionAuxData
    ) internal {
        // check that the deal is not terminated
        MarketTypes.GetDealActivationReturn memory dealActivation = MarketAPI.getDealActivation(
            dealId
        );
        require(dealActivation.terminated <= 0, "Deal is terminated");
        require(dealActivation.activated > 0, "Deal is not activated");

        MarketTypes.GetDealDataCommitmentReturn memory dealDataCommitment = MarketAPI
            .getDealDataCommitment(dealId);
        require(
            keccak256(dealDataCommitment.data) == keccak256(inclusionAuxData.commPa),
            "Deal commD doesn't match"
        );
        require(dealDataCommitment.size == inclusionAuxData.sizePa, "Deal size doesn't match");
    }

    // validateIndexEntry validates that the index entry is in the correct position in the index.
    function validateIndexEntry(InclusionProof memory ip, uint64 assumedSizePa2) internal pure {
        uint64 idxStart = indexAreaStart(assumedSizePa2);
        (bool ok3, uint64 indexOffset) = checkedMultiply(
            ip.proofIndex.index,
            BYTES_IN_DATA_SEGMENT_ENTRY
        );
        require(ok3, "indexOffset overflow");
        require(indexOffset >= idxStart, "index entry at wrong position");
    }

    // computeRoot computes the root of a Merkle tree given a leaf and a Merkle proof.
    function computeRoot(ProofData memory d, bytes32 subtree) internal pure returns (bytes32) {
        require(d.path.length < 64, "merkleproofs with depths greater than 63 are not supported");
        require(d.index >> d.path.length == 0, "index greater than width of the tree");

        bytes32 carry = subtree;
        uint64 index = d.index;
        uint64 right = 0;

        for (uint64 i = 0; i < d.path.length; i++) {
            (right, index) = (index & 1, index >> 1);
            if (right == 1) {
                carry = computeNode(d.path[i], carry);
            } else {
                carry = computeNode(carry, d.path[i]);
            }
        }

        return carry;
    }

    // computeNode computes the parent node of two child nodes
    function computeNode(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        bytes32 digest = sha256(abi.encodePacked(left, right));
        return truncate(digest);
    }

    // indexAreaStart returns the offset of the start of the index area in the deal.
    function indexAreaStart(uint64 sizePa) internal pure returns (uint64) {
        return uint64(sizePa) - uint64(maxIndexEntriesInDeal(sizePa)) * uint64(ENTRY_SIZE);
    }

    // maxIndexEntriesInDeal returns the maximum number of index entries that can be stored in a deal of the given size.
    function maxIndexEntriesInDeal(uint256 dealSize) internal pure returns (uint256) {
        uint256 res = (uint256(1) << uint256(log2Ceil(uint64(dealSize / 2048 / ENTRY_SIZE)))); //& ((1 << 256) - 1);
        if (res < 4) {
            return 4;
        }
        return res;
    }

    // isPow2 returns true if the given value is a power of 2.
    function isPow2(uint64 value) internal pure returns (bool) {
        if (value == 0) {
            return true;
        }
        return (value & (value - 1)) == 0;
    }

    // checkedMultiply multiplies two uint64 values and returns the result and a boolean indicating whether the multiplication
    function checkedMultiply(uint64 a, uint64 b) internal pure returns (bool, uint64) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint64 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    // truncate truncates a node to 254 bits.
    function truncate(bytes32 n) internal pure returns (bytes32) {
        // Set the two lowest-order bits of the last byte to 0
        return n & TRUNCATOR;
    }

    // verify verifies that the given leaf is present in the merkle tree with the given root.
    function verify(
        ProofData memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return computeRoot(proof, leaf) == root;
    }

    // processProof computes the root of the merkle tree given the leaf and the inclusion proof.
    function processProof(ProofData memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.path.length; i++) {
            computedHash = hashNode(computedHash, proof.path[i]);
        }
        return computedHash;
    }

    // hashNode hashes the given node with the given left child.
    function hashNode(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(left, right));
        truncatedData &= TRUNCATOR;
        return truncatedData;
    }

    // truncatedHash computes the truncated hash of the given data.
    function truncatedHash(bytes memory data) internal pure returns (bytes32) {
        bytes32 truncatedData = sha256(abi.encodePacked(data));
        truncatedData &= TRUNCATOR;
        return truncatedData;
    }

    // makeDataSegmentIndexEntry creates a new data segment index entry.
    function makeDataSegmentIndexEntry(
        Fr32 memory commP,
        uint64 offset,
        uint64 size
    ) internal pure returns (SegmentDesc memory) {
        SegmentDesc memory en;
        en.commDs = bytes32(commP.value);
        en.offset = offset;
        en.size = size;
        en.checksum = computeChecksum(en);
        return en;
    }

    // computeChecksum computes the checksum of the given segment description.
    function computeChecksum(SegmentDesc memory _sd) internal pure returns (bytes16) {
        bytes memory serialized = serialize(_sd);
        bytes32 digest = sha256(serialized);
        digest &= hex"ffffffffffffffffffffffffffffff3f";
        return bytes16(digest);
    }

    // serialize serializes the given segment description.
    function serialize(SegmentDesc memory sd) internal pure returns (bytes memory) {
        bytes memory result = new bytes(ENTRY_SIZE);

        // Pad commDs
        bytes32 commDs = sd.commDs;
        assembly {
            mstore(add(result, 32), commDs)
        }

        // Pad offset (little-endian)
        for (uint256 i = 0; i < 8; i++) {
            result[MERKLE_TREE_NODE_SIZE + i] = bytes1(uint8(sd.offset >> (i * 8)));
        }

        // Pad size (little-endian)
        for (uint256 i = 0; i < 8; i++) {
            result[MERKLE_TREE_NODE_SIZE + 8 + i] = bytes1(uint8(sd.size >> (i * 8)));
        }

        // Pad checksum
        for (uint256 i = 0; i < 16; i++) {
            result[MERKLE_TREE_NODE_SIZE + 16 + i] = sd.checksum[i];
        }

        return result;
    }

    // leadingZeros64 returns the number of leading zeros in the given uint64.
    function leadingZeros64(uint64 x) internal pure returns (uint256) {
        return 64 - len64(x);
    }

    // len64 returns the number of bits in the given uint64.
    function len64(uint64 x) internal pure returns (uint256) {
        uint256 count = 0;
        while (x > 0) {
            x = x >> 1;
            count++;
        }
        return count;
    }

    // log2Ceil returns the ceiling of the base-2 logarithm of the given value.
    function log2Ceil(uint64 value) internal pure returns (int256) {
        if (value <= 1) {
            return 0;
        }
        return log2Floor(value - 1) + 1;
    }

    // log2Floor returns the floor of the base-2 logarithm of the given value.
    function log2Floor(uint64 value) internal pure returns (int256) {
        if (value == 0) {
            return 0;
        }
        uint256 zeros = leadingZeros64(value);
        return int256(64 - zeros - 1);
    }
}

// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// Delta that implements the AggregatorOracle interface
contract DealStatus is IAggregatorOracle, Proof, Ownable {
    uint256 private transactionId;
    mapping(uint256 => bytes) private txIdToCid;
    mapping(bytes => Deal[]) private cidToDeals;
    uint256 public maxReplications;

    constructor(uint256 _maxReplications) Ownable() {
        transactionId = 0;
        maxReplications = _maxReplications;
    }

    function submit(bytes memory _cid) external returns (uint256) {
        // Increment the transaction ID
        transactionId++;

        // Save _cid
        txIdToCid[transactionId] = _cid;

        // Emit the event
        emit SubmitAggregatorRequest(transactionId, _cid);
        return transactionId;
    }

    function submitRaaS(
        bytes memory _cid,
        uint256 _replication_target,
        uint256 _repair_threshold,
        uint256 _renew_threshold
    ) external returns (uint256) {
        // Increment the transaction ID
        require(_replication_target <= maxReplications, "Replications exceeding the limit");
        transactionId++;

        // Save _cid
        txIdToCid[transactionId] = _cid;

        // Emit the event
        emit SubmitAggregatorRequestWithRaaS(
            transactionId,
            _cid,
            _replication_target,
            _repair_threshold,
            _renew_threshold
        );
        return transactionId;
    }

    function complete(
        uint256 _id,
        uint64 _dealId,
        uint64 _minerId,
        InclusionProof memory _proof,
        InclusionVerifierData memory _verifierData
    ) external returns (InclusionAuxData memory) {
        require(_id <= transactionId, "Delta.complete: invalid tx id");
        // Emit the event
        emit CompleteAggregatorRequest(_id, _dealId);

        // save the _dealId if it is not already saved
        bytes memory cid = txIdToCid[_id];
        for (uint256 i = 0; i < cidToDeals[cid].length; i++) {
            if (cidToDeals[cid][i].dealId == _dealId) {
                return computeExpectedAuxData(_proof, _verifierData);
            }
        }

        Deal memory deal = Deal(_dealId, _minerId);
        cidToDeals[cid].push(deal);

        // Perform validation logic
        // return this.computeExpectedAuxDataWithDeal(_dealId, _proof, _verifierData);
        return computeExpectedAuxData(_proof, _verifierData);
    }

    // allDealIds should return all the deal ids created by the aggregator
    function getAllDeals(bytes memory _cid) external view returns (Deal[] memory) {
        return cidToDeals[_cid];
    }

    function getAllCIDs() external view returns (bytes[] memory) {
        bytes[] memory cids = new bytes[](transactionId);
        for (uint256 i = 0; i < transactionId; i++) {
            cids[i] = txIdToCid[i + 1];
        }
        return cids;
    }

    // getActiveDeals should return all the _cid's active dealIds
    function getActiveDeals(bytes memory _cid) external returns (Deal[] memory) {
        // get all the deal ids for the cid
        Deal[] memory activeDealIds;
        activeDealIds = this.getAllDeals(_cid);

        for (uint256 i = 0; i < activeDealIds.length; i++) {
            uint64 dealID = activeDealIds[i].dealId;
            // get the deal's expiration epoch
            MarketTypes.GetDealActivationReturn memory dealActivationStatus = MarketAPI
                .getDealActivation(dealID);

            if (dealActivationStatus.terminated > 0 || dealActivationStatus.activated == -1) {
                delete activeDealIds[i];
            }
        }

        return activeDealIds;
    }

    // getExpiringDeals should return all the deals' dealIds if they are expiring within `epochs`
    function getExpiringDeals(bytes memory _cid, uint64 epochs) external returns (Deal[] memory) {
        // the logic is similar to the above, but use this api call:
        // https://github.com/Zondax/filecoin-solidity/blob/master/contracts/v0.8/MarketAPI.sol#LL110C9-L110C9
        Deal[] memory expiringDealIds;
        expiringDealIds = this.getAllDeals(_cid);

        for (uint256 i = 0; i < expiringDealIds.length; i++) {
            uint64 dealId = expiringDealIds[i].dealId;
            // get the deal's expiration epoch
            MarketTypes.GetDealTermReturn memory dealTerm = MarketAPI.getDealTerm(dealId);

            if (
                block.number < uint64(dealTerm.end) - epochs || block.number > uint64(dealTerm.end)
            ) {
                delete expiringDealIds[i];
            }
        }

        return expiringDealIds;
    }

    function changeMaxReplications(uint256 _maxReplications) external onlyOwner {
        maxReplications = _maxReplications;
    }

    function getMaxReplications() external view returns (uint256) {
        return maxReplications;
    }
}