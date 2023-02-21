// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

library Queue{
    error Empty();

    struct queue {
        uint begin;
        uint end;
        mapping(uint => uint) data;
    }
    
    function append(queue storage q, uint data) internal {
        uint end = q.end;
        q.data[end] = data;
        q.end += 1;
    }

    function popLeft(queue storage q) internal returns(uint) {
        if(isEmpty(q)) {
            revert Empty();
        }

        uint front = q.data[q.begin];

        delete q.data[q.begin];
        q.begin += 1;
        return front;
    }

    function setClear(queue storage q) internal {
        q.begin = 0;
        q.end = 0;
    }

    function getLength(queue storage q) internal view returns(uint) {
        return q.end - q.begin;
    }

    function isEmpty(queue storage q) internal view returns(bool) {
        return q.begin >= q.end;
    }
}