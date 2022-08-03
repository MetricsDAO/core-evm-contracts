//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

//https://www.happycoders.eu/algorithms/red-black-tree-java/
contract RedBlack {
    TreeNode private _root;
    TreeNode[] private _nodes;
    Content[] private _content;

    constructor() {}

    function insert(uint256 sortValue) public {
        TreeNode memory node = _root;
        TreeNode memory parent;

        // find where the new insertion goes
        while (node.isSet) {
            parent = node;
            if (sortValue < node.sortValue) {
                node = _nodes[node.leftChildIndex];
            } else if (sortValue >= node.sortValue) {
                node = _nodes[node.rightChildIndex];
            } else {
                // TODO handle dupes
            }
        }

        TreeNode memory newNode = TreeNode({
            contentIndex: 0,
            sortValue: sortValue,
            isSet: true,
            nodeIndex: 0,
            leftChildIndex: 0,
            rightChildIndex: 0,
            parentIndex: 0,
            isRed: true
        });
        _nodes.push(newNode);
        _nodes[_nodes.length - 1].nodeIndex = _nodes.length - 1;

        if (!parent.isSet || !_root.isSet) {
            _root = newNode;
        } else if (sortValue < parent.sortValue) {
            parent.leftChildIndex = newNode.nodeIndex;
        } else {
            parent.rightChildIndex = newNode.nodeIndex;
        }
        _nodes[_nodes.length - 1].parentIndex = parent.nodeIndex;
        fixRedBlackPropertiesAfterInsert(newNode);
    }

    function remove() public view {}

    function get(uint256 offset, uint256 limit) public view returns (uint256[] memory ret) {}

    function getSorted() private view {
        uint256[] memory sorted;
        traverseInOrder(_root, sorted);
    }

    function traverseInOrder(TreeNode memory node, uint256[] memory sorted) private view {
        if (!node.isSet) {
            traverseInOrder(_nodes[node.leftChildIndex], sorted);
            sorted[sorted.length] = (node.nodeIndex);
            traverseInOrder(_nodes[node.rightChildIndex], sorted);
        }
    }

    function searchNode(uint256 targetsortValue) private view returns (TreeNode memory) {
        TreeNode memory node = _root;
        while (node.isSet) {
            if (targetsortValue == node.sortValue) {
                return node;
            } else if (targetsortValue < node.sortValue) {
                node = _nodes[node.leftChildIndex];
            } else {
                node = _nodes[node.rightChildIndex];
            }
        }

        return _root;
        // TODO error if not found?
    }

    function rotateRight(TreeNode memory node) private {
        TreeNode memory parent = _nodes[node.parentIndex];
        TreeNode memory leftChild = _nodes[node.leftChildIndex];

        node.leftChildIndex = leftChild.rightChildIndex;
        if (_nodes[leftChild.rightChildIndex].isSet) {
            _nodes[leftChild.rightChildIndex].parentIndex = node.nodeIndex;
        }

        leftChild.rightChildIndex = node.nodeIndex;
        node.parentIndex = leftChild.nodeIndex;

        replaceParentsChild(parent, node, leftChild);
    }

    function rotateLeft(TreeNode memory node) private {
        TreeNode memory parent = _nodes[node.parentIndex];
        TreeNode memory rightChild = _nodes[node.rightChildIndex];

        node.rightChildIndex = rightChild.leftChildIndex;
        if (_nodes[rightChild.leftChildIndex].isSet) {
            _nodes[rightChild.leftChildIndex].parentIndex = node.nodeIndex;
        }

        rightChild.leftChildIndex = node.nodeIndex;
        node.parentIndex = rightChild.nodeIndex;

        replaceParentsChild(parent, node, rightChild);
    }

    function replaceParentsChild(
        TreeNode memory parent,
        TreeNode memory oldChild,
        TreeNode memory newChild
    ) private {
        if (!parent.isSet) {
            _root = newChild;
        } else if (_nodes[parent.leftChildIndex].sortValue == oldChild.sortValue) {
            parent.leftChildIndex = newChild.nodeIndex;
        } else if (_nodes[parent.leftChildIndex].sortValue == oldChild.sortValue) {
            parent.rightChildIndex = newChild.nodeIndex;
        } else {
            revert NodeNotChild();
        }

        if (newChild.isSet) {
            newChild.parentIndex = parent.nodeIndex;
        }
    }

    function fixRedBlackPropertiesAfterInsert(TreeNode memory node) private {
        TreeNode memory parent = _nodes[node.parentIndex];

        // Case 1: Parent is null, we've reached the root, the end of the recursion
        if (!parent.isSet) {
            // Uncomment the following line if you want to enforce black roots (rule 2):
            // node.color = BLACK;
            return;
        }

        // Parent is black --> nothing to do
        if (parent.isRed == false) {
            return;
        }

        // From here on, parent is red
        TreeNode memory grandparent = _nodes[parent.parentIndex];

        // Case 2:
        // Not having a grandparent means that parent is the root. If we enforce black roots
        // (rule 2), grandparent will never be null, and the following if-then block can be
        // removed.
        if (!grandparent.isSet) {
            // As this method is only called on red nodes (either on newly inserted ones - or -
            // recursively on red grandparents), all we have to do is to recolor the root black.
            parent.isRed = false;
            return;
        }

        // Get the uncle (may be null/nil, in which case its color is BLACK)
        TreeNode memory uncle = getUncle(parent);

        // Case 3: Uncle is red -> recolor parent, grandparent and uncle
        if (uncle.isSet && uncle.isRed) {
            parent.isRed = false;
            grandparent.isRed = true;
            uncle.isRed = false;

            // Call recursively for grandparent, which is now red.
            // It might be root or have a red parent, in which case we need to fix more...
            fixRedBlackPropertiesAfterInsert(grandparent);
        }
        // Parent is left child of grandparent
        else if (parent.sortValue == _nodes[grandparent.leftChildIndex].sortValue) {
            // Case 4a: Uncle is black and node is left->right "inner child" of its grandparent
            if (node.sortValue == parent.sortValue) {
                rotateLeft(parent);

                // Let "parent" point to the new root node of the rotated sub-tree.
                // It will be recolored in the next step, which we're going to fall-through to.
                parent = node;
            }

            // Case 5a: Uncle is black and node is left->left "outer child" of its grandparent
            rotateRight(grandparent);

            // Recolor original parent and grandparent
            parent.isRed = false;
            grandparent.isRed = true;
        }
        // Parent is right child of grandparent
        else {
            // Case 4b: Uncle is black and node is right->left "inner child" of its grandparent
            if (node.sortValue == _nodes[parent.leftChildIndex].sortValue) {
                rotateRight(parent);

                // Let "parent" point to the new root node of the rotated sub-tree.
                // It will be recolored in the next step, which we're going to fall-through to.
                parent = node;
            }

            // Case 5b: Uncle is black and node is right->right "outer child" of its grandparent
            rotateLeft(grandparent);

            // Recolor original parent and grandparent
            parent.isRed = false;
            grandparent.isRed = true;
        }
    }

    function getUncle(TreeNode memory parent) private view returns (TreeNode memory) {
        TreeNode memory grandparent = _nodes[parent.parentIndex];
        if (_nodes[grandparent.leftChildIndex].sortValue == parent.sortValue) {
            return _nodes[grandparent.rightChildIndex];
        } else if (_nodes[grandparent.rightChildIndex].sortValue == parent.sortValue) {
            return _nodes[grandparent.leftChildIndex];
        } else {
            revert NodeNotChild();
            // throw new IllegalStateException("Parent is not a child of its grandparent");
        }
    }

    error NodeNotChild();

    struct TreeNode {
        uint256 contentIndex;
        //
        uint256 sortValue;
        uint256 nodeIndex;
        uint256 leftChildIndex;
        uint256 rightChildIndex;
        uint256 parentIndex;
        bool isSet;
        //
        bool isRed;
    }

    struct Content {
        uint256 tokenId;
        string url;
        //
    }
}
