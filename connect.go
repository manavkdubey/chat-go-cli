package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"strings"

	"github.com/libp2p/go-libp2p"
	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/peerstore"
	"github.com/multiformats/go-multiaddr"
)

func handleStream(s network.Stream) {
	log.Println("Got a new stream!")

	// Create a buffer stream for non-blocking read and write.
	rw := bufio.NewReadWriter(bufio.NewReader(s), bufio.NewWriter(s))

	go readData(rw)
	go writeData(rw)

}
func readData(rw *bufio.ReadWriter) {
	for {
		bytes, err := rw.ReadBytes('\n')
		if err != nil {
			log.Println(err)

		}

		if len(bytes) == 0 {
			return
		}
		msg, _ := BytesToMessage(bytes)
		if msg.Message != "\n" {
			// fmt.Printf(msg.User.Name, msg.Message)
			// Green console colour: 	\x1b[32m
			// Reset console colour: 	\x1b[0m
			fmt.Printf("\x1b[32m%s : %s\x1b[0m\n>", msg.User.Name, msg.Message)
		}

	}
}

func writeData(rw *bufio.ReadWriter) {
	stdReader := bufio.NewReader(os.Stdin)

	for {
		fmt.Print("> ")
		sendData, err := stdReader.ReadString('\n')
		if err != nil {
			log.Println(err)
			return
		}
		sendData = strings.TrimRight(sendData, "\r\n") // remove user's newline
		user := User{Id: "abc", Name: "User", PasswordHash: "0"}
		bytes, err := MessageBytes(sendData, user)
		if err != nil {
			log.Println(err)
			continue
		}
		// write JSON bytes, then a newline delimiter so receiver can ReadBytes('\n')
		if _, err := rw.Write(bytes); err != nil {
			log.Println("write error:", err)
			return
		}
		if _, err := rw.Write([]byte("\n")); err != nil {
			log.Println("write delimiter error:", err)
			return
		}
		if err := rw.Flush(); err != nil {
			log.Println("flush error:", err)
			return
		}
	}
}

func makeHost(port int, randomness io.Reader) (host.Host, error) {

	prvKey, _, err := crypto.GenerateKeyPairWithReader(crypto.RSA, 2048, randomness)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	sourceMultiAddr, _ := multiaddr.NewMultiaddr(fmt.Sprintf("/ip4/0.0.0.0/tcp/%d", port))

	return libp2p.New(
		libp2p.ListenAddrs(sourceMultiAddr),
		libp2p.Identity(prvKey),
	)
}
func startPeer(_ context.Context, h host.Host, streamHandler network.StreamHandler) {
	h.SetStreamHandler("/chat/1.0.0", streamHandler)
	var port string
	for _, la := range h.Network().ListenAddresses() {
		if p, err := la.ValueForProtocol(multiaddr.P_TCP); err == nil {
			port = p
			break
		}
	}
	if port == "" {
		log.Println("was not able to find actual local port")
		return
	}
	log.Printf("Run 'go run . -d /ip4/127.0.0.1/tcp/%v/p2p/%s' on another console.\n", port, h.ID())
	log.Println("Waiting for incoming connection")
	log.Println()
}

func startPeerAndConnect(_ context.Context, h host.Host, destination string) (*bufio.ReadWriter, error) {
	log.Println("This node's multiaddresses:")
	for _, la := range h.Addrs() {
		log.Printf(" - %v\n", la)
	}
	log.Println()

	maddr, err := multiaddr.NewMultiaddr(destination)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	info, err := peer.AddrInfoFromP2pAddr(maddr)
	if err != nil {
		log.Println(err)
		return nil, err
	}

	h.Peerstore().AddAddrs(info.ID, info.Addrs, peerstore.PermanentAddrTTL)

	s, err := h.NewStream(context.Background(), info.ID, "/chat/1.0.0")
	if err != nil {
		log.Println(err)
		return nil, err
	}
	log.Println("Established connection to destination")

	rw := bufio.NewReadWriter(bufio.NewReader(s), bufio.NewWriter(s))

	return rw, nil
}
